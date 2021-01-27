#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  globals.sh                                            ###
###                                                        ###
###  this is the guts of gcloudrig; it's not meant to be   ###
###  run directly!                                         ###
###                                                        ###
##############################################################
# bash "what directory am i" dance
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# emergency debug
set -e; [ -n "$GCLOUDRIG_DEBUG" ] && set -x
source "$DIR/config.sh"
##############################################################

########
# INIT #
########

function init_gcloudrig {

  DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd)"

  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$(gcloud config get-value core/project --quiet 2> /dev/null)"
    
    # Still no project? run config setup
    if [ -z "$PROJECT_ID" ]; then
      gcloudrig_config_setup
    fi
  fi

  if [ -z "$REGION" ]; then
    REGION="$(gcloud config get-value compute/region --quiet 2> /dev/null)"
    
    # Cloud Shell doesn't persist configurations, so look at project_ID metadata instead
    if [ -z "$REGION" ]; then
      REGION="$(gcloud compute project-info describe --project="$PROJECT_ID" --format 'value(commonInstanceMetadata.items[google-compute-default-region])' --quiet 2> /dev/null)"
    fi
  fi

  # if we don't have a project id or region yet
  if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
    # check if we're running in cloudshell, since it likes to eat gcloud configs
    GCE_ATTRIBUTE_BASE_SERVER_URL="$(curl -H "Metadata-Flavor: Google" metadata/computeMetadata/v1/instance/attributes/base-server-url)"
    if [ "$GCE_ATTRIBUTE_BASE_SERVER_URL" == "https://ssh.cloud.google.com" ]; then
      gcloudrig_config_setup
    fi
  fi

  # if we still don't have a project id or region, bail and ask user to run setup
  if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
    [ -z "$PROJECT_ID" ] && echo "Missing config 'core/project'" >&2
    [ -z "$REGION" ] && echo "Missing config 'compute/region'" >&2
    echo "Please run './setup.sh'" >&2
    exit 1
  fi

  init_common
}

function init_setup {
  DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd)"

  if [ -n "$REGION" ] && [ -n "$PROJECT_ID" ] ; then
    # using settings at the top of this file
    enable_required_gcloud_apis
  else
    # use gcloud config configurations
    gcloudrig_config_setup
  fi

  # not all accounts seem to have a GPUS_ALL_REGIONS quota
  # but if they do it must be manually increased
  gcloudrig_check_quota_gpus_all_regions

  # create a GCS bucket to store Powershell module
  gcloudrig_create_gcs_bucket

  # now set the zones
  init_common;
}

function init_common {
  GCSBUCKET="gs://$PROJECT_ID"
  local groupsize=0

  # get a comma separated list of zones with accelerators in the current region
  ZONES="$(gcloudrig_get_accelerator_zones "$REGION")"
  ZONES="${ZONES//[[:space:]]/,}"
  if [ -z "$ZONES" ] ; then
    gcloud config unset compute/zone --quiet
    gcloud config unset compute/region --quiet
    echo >&2
    echo "#################################################################" >&2
    echo "ERROR: There are no zones in $REGION with accelerator type \"$ACCELERATORTYPE\"" >&2
    echo "Re-run ./setup.sh and choose a region from this list:" >&2
    # shellcheck disable=SC2005
    echo "$(gcloudrig_get_accelerator_zones)" >&2
    exit 1
  fi

  # get the number of instances currently running
  groupsize=$(gcloud compute instance-groups list --filter "name=$INSTANCEGROUP region:($REGION)" --format "value(size)" --quiet || echo "0")

  # if an instance is running, expose some more vars
  if [ -n "$groupsize" ] && [ "$groupsize" -gt "0" ]; then
    INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
    ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"
    BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"
    gcloud config set compute/zone "$ZONE" --quiet;
  fi

  # the image 
  IMAGE=$(gcloudrig_get_bootimage)
  if [ -z "$IMAGE" ]; then
    IMAGE="$IMAGEFAMILY"
  fi
}

####################
# Setup functions  #
####################

function gcloudrig_config_setup {
  # setup a gcloud config manually so we can make sure the user only chooses a
  # region that has GPUs

  # activate the default config, or create if not found
  if [ -z "$(gcloud config configurations list --filter "name=($CONFIGURATION)" --format "value(name)" --quiet)" ]; then
    # create and activate
    gcloud config configurations create "$CONFIGURATION" --quiet
  else
    gcloud config configurations activate "$CONFIGURATION" --quiet
  fi

  # setup auth
  if [ -z "$(gcloud config get-value account 2>/dev/null)" ] ; then
    ACCOUNTS="$(gcloud auth list --format "value(account)")"
    if [ -n "$ACCOUNTS" ] ; then
      echo
      echo "Select account to use:"
      select acct in $ACCOUNTS "new account"; do
        if [ -n "$acct" ] ; then
          if [ "$acct" == "new account" ] ; then
            gcloud auth login --no-launch-browser && break
          else
            gcloud config set account "$acct" --quiet && break
          fi
        fi
      done
    else
      gcloud auth login --no-launch-browser
    fi
  fi

  # check if default project_ID is set, if not select/create one
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
  if [ -z "$PROJECT_ID" ] ; then
    OLDIFS=$IFS; IFS=$'\n';
    declare -A PROJECTS
    for line in $(gcloud projects list --format="csv[no-heading](name,project_id)"); do
      PROJECTS[${line%%,*}]="${line##*,}"
    done;
    if [ "${#PROJECTS[@]}" -eq 0 ] ; then
      # no existing projects, create one
      PROJECT_ID="gcloudrig-${RANDOM}${RANDOM}"
      gcloud_projects_create "$PROJECT_ID"
    else
      echo
      echo "Select project to use:"
      select project in "${!PROJECTS[@]}" "(new project)" ; do
        if [ -n "$project" ] ; then
          if [ "$project" == "(new project)" ] ; then
            # user requested to use a new project
            PROJECT_ID="gcloudrig-${RANDOM}${RANDOM}"
            gcloud_projects_create "$PROJECT_ID"
          else
            PROJECT_ID="${PROJECTS[$project]}"
            gcloud config set project "$PROJECT_ID" --quiet
          fi
          break
        fi
      done
    fi
    IFS=$OLDIFS
  fi

  # this is required before we can check for regions with GPUs
  enable_required_gcloud_apis

  # check default region is set in configuration, if not select one from regions with accelerators
  REGION="$(gcloud config get-value compute/region 2>/dev/null)"
  if [ -z "$REGION" ] ; then
    gcloudrig_select_region
  fi
}

function gcloudrig_select_software_options {
  local installerOptions
  local keys
  keys="$(echo "${!SETUPOPTIONS[@]}" | fmt -1 | sort)"

  while true ; do
    installerOptions=""
    for key in $keys ; do
      installerOptions="$installerOptions $key=${SETUPOPTIONS[$key]}"
    done

    echo
    select option in $installerOptions Done ; do
      case "$option" in
        ZeroTier*)
          gcloudrig_select_zerotier_network
          break
          ;;
        VideoMode*)
          gcloudrig_select_videomode
          break
          ;;
        DisplayScaling*)
          gcloudrig_select_displayscaling
          break
          ;;
        Install*)
          gcloudrig_select_software_install "$option"
          break
          ;;
        Done)
          break 2
          ;;
      esac
    done
  done
}

function gcloudrig_select_software_install {
  local package="${1%%=*}"
  local state="${1##*=}"

  case "$state" in
    true)
      SETUPOPTIONS[$package]=false
      ;;
    false)
      SETUPOPTIONS[$package]=true
      ;;
  esac
}

function gcloudrig_select_videomode {
  local videoModes="960x720 1920x1080 2560x1440 other"

  echo "Select a default videomode:"
  select mode in $videoModes ; do
    if [ -n "$mode" ] ; then
      [ "$mode" == "other" ] && break
      SETUPOPTIONS[VideoMode]="$mode"
      break
    fi
  done
}

function gcloudrig_select_displayscaling {
  local DPI_modes="96 144 other"

  echo "Select DPI Display Scaling:"
  select mode in $DPI_modes ; do
    if [ -n "$mode" ] ; then
      [ "$mode" == "other" ] && break
      SETUPOPTIONS[DisplayScaling]="$mode"
      break
    fi
  done
}

function gcloudrig_select_zerotier_network {
  local prompt="Enter the ZeroTier Network ID [or quit]: " 

  cat <<EOF

We strongly recommend you create a new ZeroTier network for gcloudrig
https://my.zerotier.com/network

EOF

  while read -r -e -p "$prompt" ; do
    if echo "$REPLY" | grep -Eiq '^[0-9a-f]{16}$' ; then
      SETUPOPTIONS[ZeroTierNetwork]="$REPLY"
      return
    fi
    case "$REPLY" in
      q|quit|exit|cancel)
        break
        ;;
      *)
        echo "ZeroTier Network IDs are 16 hexadecimal numbers" >&2
    esac
  done
}

function gcloudrig_select_region {

  local ACCELERATORREGIONS
  ACCELERATORREGIONS="$(gcloudrig_get_accelerator_zones | sed -ne 's/-[a-z]$//p' | sort -u)"

  if [ -n "$ACCELERATORREGIONS" ] ; then
    echo
    echo "You can use https://cloudharmony.com/speedtest-latency-for-google:compute to test for latency and find your closest region"
    echo
    echo "Select a region to use:"
    select REGION in $ACCELERATORREGIONS ; do
      [ -n "$REGION" ] && gcloud config set compute/region "$REGION" --quiet && gcloud compute project-info add-metadata \
    --metadata google-compute-default-region="$REGION" --quiet && break
    done
  else
    echo >&2
    echo "#################################################################" >&2
    echo "ERROR: no regions with accelerator type \"$ACCELERATORTYPE\" found " >&2
    exit 1
  fi
}

function gcloud_projects_create {
  local PROJECT_ID="$1"

  gcloud projects create "$PROJECT_ID" --name gcloudrig --set-as-default
  echo "You need to enable billing, then re-run setup.sh"
  echo "https://console.developers.google.com/project/${PROJECT_ID}/settings"
  exit 1
}

function enable_required_gcloud_apis {
  # check if compute api is enabled, if not enable it
  local COMPUTEAPI
  COMPUTEAPI=$(gcloud services list --format "value(config.name)" --filter "config.name=compute.googleapis.com" --quiet)
  if [ "$COMPUTEAPI" != "compute.googleapis.com" ]; then
    echo "Enabling Compute API..."
    gcloud services enable compute.googleapis.com
  fi

  # check if logging api is enabled, if not enable it
  local LOGGINGAPI
  LOGGINGAPI=$(gcloud services list --format "value(config.name)" --filter "config.name=logging.googleapis.com" --quiet)
  if [ "$LOGGINGAPI" != "logging.googleapis.com" ]; then
    echo "Enabling Logging API..."
    gcloud services enable logging.googleapis.com
  fi
}

####################
# GETTERS (stdout) #
####################

# Get instance name from instance group
function gcloudrig_get_instance_from_group {
  local instance_group="$1"
  gcloud compute instance-groups list-instances "$instance_group" \
    --format "value(instance)" \
    --region "$REGION" \
    --quiet
}

# Get instance zone from instance group
function gcloudrig_get_instance_zone_from_group {
  local instance_group="$1"
  gcloud compute instance-groups list-instances "$instance_group" \
    --format "value(instance.scope().segment(0))" \
    --region "$REGION" \
    --quiet
}

# Get bootdisk from instance
function gcloudrig_get_bootdisk_from_instance {
  local zone="$1"
  local instance="$2"
  gcloud compute instances describe "$instance" \
    --zone "$zone" \
    --format "value(disks[0].source.basename())" \
    --quiet
}

# Get boot image
function gcloudrig_get_bootimage {
  gcloud compute images list \
    --format "value(name)" \
    --filter "labels.$GCRLABEL=true labels.latest=true"
}

# Get zones with accelerators in region $1
# if $1 is not specified, all regions
function gcloudrig_get_accelerator_zones {
  local region="${1:-*}"
  gcloud compute accelerator-types list \
    --filter "zone:$region AND name=$ACCELERATORTYPE" \
    --format "value(zone)"
}


##################
# INSTANCE GROUP #
##################

function gcloudrig_create_instance_template {
  local templateName="$1" # required
  local imageFlags
  local bootImage
  local preemptibleFlags

  if [ -n "$PREEMPTIBLE" ]; then
    preemptibleFlags="--preemptible"
  fi

  bootImage=$(gcloudrig_get_bootimage)

  # if the templateName is SETUPTEMPLATE or we still don't have a custom boot image, assume we're in setup
  if [ "$templateName" == "$SETUPTEMPLATE" ] || [ -z "$bootImage" ]; then
    imageFlags="--image-family $IMAGEBASEFAMILY --image-project $IMAGEBASEPROJECT"
  else
    imageFlags="--image $(gcloudrig_get_bootimage)"
  fi

  echo "Modifying gcloudrig-boot.ps1 variables..."
  #shellcheck disable=SC2016
  sed -i 's/^$GcloudrigPrefix\=.*/$GcloudrigPrefix="'"$GCLOUDRIG_PREFIX"'"/' "$DIR/gcloudrig-boot.ps1"
  #shellcheck disable=SC2016
  sed -i 's/^$GCPLabel\=.*/$GCPLabel="'"$GCLOUDRIG_PREFIX"'"/' "$DIR/gcloudrig-boot.ps1"
  #shellcheck disable=SC2016
  sed -i 's/^$GamesDiskName\=.*/$GamesDiskName="'"$GAMESDISK"'"/' "$DIR/gcloudrig-boot.ps1"

  echo "Creating instance template '$templateName'..."

  #shellcheck disable=SC2086
  gcloud compute instance-templates create "$templateName" \
      --accelerator "type=$ACCELERATORTYPE,count=$ACCELERATORCOUNT" \
      --boot-disk-type "$BOOTTYPE" \
      $imageFlags \
      --labels "$GCRLABEL=true" \
      --machine-type "$INSTANCETYPE" \
      --maintenance-policy "TERMINATE" \
      --scopes "default,compute-rw" \
      --boot-disk-auto-delete \
      --no-restart-on-failure \
      "$preemptibleFlags" \
      --format "value(name)" \
      --metadata serial-port-logging-enable=true \
      --metadata-from-file windows-startup-script-ps1=<(cat "$DIR/gcloudrig-boot.ps1") \
      --quiet || echo
}

# creates regional managed instance group and gives it the base instance template
function gcloudrig_create_instance_group {
  local templateName
  local bootImage
  bootImage="$(gcloudrig_get_bootimage)"

  # if we don't have a custom boot image, assume we're in setup
  if [ -z "$bootImage" ] ; then
    templateName="$SETUPTEMPLATE"
  else
    templateName="gcloudrig-template-$(date +"%Y%m%d%H%M%S")"
  fi

  gcloudrig_create_instance_template "$templateName"

  echo "Creating managed instance group '$INSTANCEGROUP'..."
  gcloud compute instance-groups managed create "$INSTANCEGROUP" \
    --base-instance-name "$INSTANCENAME" \
    --region "$REGION" \
    --size "0" \
    --template "$templateName" \
    --zones "$ZONES" \
    --format "value(name)" \
    --quiet
}

# updates existing instance group with a new template that uses the latest image
function gcloudrig_update_instance_group {

  # new template's name
  local newtemplate
  newtemplate="gcloudrig-template-$(date +"%Y%m%d%H%M%S")"

  # create new template
  gcloudrig_create_instance_template "$newtemplate"

  # update instance group with the new template
  gcloud compute instance-groups managed set-instance-template "$INSTANCEGROUP" --region "$REGION" --template "$newtemplate" --format "value(name)" --quiet 

  # tidy up - delete all other templates
  local templates=()
  mapfile -t templates < <(gcloud compute instance-templates list \
    --format "value(name)" \
    --filter "properties.labels.$GCRLABEL=true")
  for template in "${templates[@]}"; do
    if ! [ "$newtemplate" == "$template" ]; then
      gcloud compute instance-templates delete "$template" --format "value(name)" --quiet || echo -n
    fi
  done
}

# deletes existing instance group and all templates
function gcloudrig_delete_instance_group {
  if [ -n "$(gcloud compute instance-groups list --filter "name=$INSTANCEGROUP region:($REGION)" --format "value(name)" --quiet)" ]; then
    gcloud compute instance-groups managed delete "$INSTANCEGROUP" \
      --region "$REGION" \
      --quiet
  fi

  # tidy up - delete all other templates
  local templates=()
  mapfile -t templates < <(gcloud compute instance-templates list \
    --format "value(name)" \
    --filter "properties.labels.$GCRLABEL=true")
  for template in "${templates[@]}"; do
    gcloud compute instance-templates delete "$template" --quiet || echo -n
  done
}

##################
# QUOTA COMMANDS #
##################

function gcloudrig_get_project_quota_limits {
  declare -gA QUOTAS
  OLDIFS=$IFS; IFS=$'\n';
  for line in $(gcloud compute project-info describe \
    --project="$PROJECT_ID" \
    --flatten="quotas[]" \
    --format="csv[no-heading](quotas.metric,quotas.limit)") ; do
    QUOTAS[${line%%,*}]="${line##*,}"
  done
  IFS=$OLDIFS
}

function gcloudrig_check_quota_gpus_all_regions {
  if [ ! -v QUOTAS ] ; then
    gcloudrig_get_project_quota_limits
  fi

  # if key exists in array
  if [ -v "QUOTAS[GPUS_ALL_REGIONS]" ] ; then
    # gcloud --format option sometimes outputs nothing if the value is 0.0
    if [ -z "${QUOTAS[GPUS_ALL_REGIONS]}" ] || [ "${QUOTAS[GPUS_ALL_REGIONS]}" == "0.0" ] ; then
      echo "GPU Quota Check: GPUS_ALL_REGIONS NOT_OK (limit: ${QUOTAS["GPUS_ALL_REGIONS"]})"

      cat <<EOF >&2

=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=

You have to manually request a quota increase for GPUS_ALL_REGIONS
  https://console.cloud.google.com/iam-admin/quotas?project=${PROJECT_ID}&metric=GPUs%20(all%20regions)

See this page for more info on requesting quota:
  https://cloud.google.com/compute/quotas#requesting_additional_quota

=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=

EOF
      exit 1
    else
      echo "GPU Quota Check: GPUS_ALL_REGIONS OK (limit: ${QUOTAS["GPUS_ALL_REGIONS"]})"
    fi
  else
    echo "GPU Quota Check: GPUS_ALL_REGIONS OK (no limit)"
  fi
}

##################
# OTHER COMMANDS #
##################

function gcloudrig_enable_software_setup {
  # set project level metadata that gcloudrig-boot.ps1 will check to start a
  # software install
  echo "Enabling gcloudrig software installer..."
  gcloud compute project-info add-metadata --quiet \
    --metadata "gcloudrig-setup-state=new" \
    --metadata-from-file gcloudrig-setup-options=<(gcloudrig_setup_options_to_json) 
}

function gcloudrig_setup_options_to_json {
  # all this to avoid asking ppl to install jq...
  local jsonTemplate='{%s}'
  local optionTemplate='"%s":"%s"'
  local booleanTemplate='"%s":%s'
  local optionString=""
  local key value

  if [ "${#SETUPOPTIONS[@]}" -eq 0 ] ; then
    return
  fi

  for key in "${!SETUPOPTIONS[@]}" ; do
    value="${SETUPOPTIONS[$key]}"
    value="${value//\'}" # nuke single quotes
    value="${value//\"}" # nuke double quotes
    if [ "$value" == "true" ] || [ "$value" == "false" ] ; then
      #shellcheck disable=SC2059
      optionString="$(printf "$booleanTemplate" "$key" "$value"),$optionString"
    else
      #shellcheck disable=SC2059
      optionString="$(printf "$optionTemplate" "$key" "$value"),$optionString"
    fi
  done

  # trim any trailing ','
  optionString="${optionString%,}"

  #shellcheck disable=SC2059
  printf "$jsonTemplate" "$optionString"
}

# TODO store the password somewhere safer
function gcloudrig_get_password_from_logs {
  gcloud logging read "logName=projects/$PROJECT_ID/logs/gcloudrig-install AND textPayload:password" --format="value(textPayload)" --limit=1
}

# TODO store the password somewhere safer
function gcloudrig_get_password_from_logs {
  gcloud logging read "logName=projects/$PROJECT_ID/logs/gcloudrig-install AND textPayload:password" --format="value(textPayload)" --limit=1
}

# create GCS bucket, don't fail if it already exists
function gcloudrig_create_gcs_bucket {
  local err result
  GCSBUCKET="${GCSBUCKET:-gs://$PROJECT_ID}"

  set +e
  result="$(gsutil -q mb -p "$PROJECT_ID" -c regional \
    -l "$REGION" "$GCSBUCKET/" 2>&1)"
  err="$?"
  if [ "$err" -gt 0 ] ; then
    # catch errors, ignore "already exists"
    if ! echo "$result" | grep -q "already exists" ; then
      echo "$result" >&2
      return "$err"
    fi
  fi
  set -e

  # announce script's gcs url via project metadata
  gcloud compute project-info add-metadata --metadata "gcloudrig-setup-script-gcs-url=$GCSBUCKET/gcloudrig.psm1" --quiet
}

function gcloudrig_update_powershell_module {
  # TODO only update if newer
  local quiet=""
  [ -n "$GCLOUDRIG_DEBUG" ] && quiet="-q"
  gsutil $quiet cp "$DIR/gcloudrig.psm1" "$GCSBUCKET/"
}

function wait_until_instance_group_is_stable {
  set +e
  timeout 300s gcloud compute instance-groups managed wait-until --stable "$INSTANCEGROUP" \
  	--region "$REGION" \
    --quiet

  err=$?
  set -e

  if [ "$err" -gt "0" ]; then
    gcloud logging read 'severity>=WARNING' \
      --freshness 10m \
      --format "table[box,title='-- Recent logs (10m) --'](timestamp,protoPayload.status.message)"
    return $err
  fi
}

function gcloudrig_set_running_instance_zone_bootdisk {
  INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
  ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"
  BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"
}

# scale to 1 and wait, with retries every 5 minutes
function gcloudrig_start {
  echo "Starting gcloudrig..."

  gcloudrig_update_powershell_module

  # scale to 1
  gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
    --size "1" \
    --format "value(currentActions)" \
    --region "$REGION" \
    --quiet &>/dev/null

  # if it doesn't start in 5 minutes
  while ! wait_until_instance_group_is_stable; do

    # scale it back down
    gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
      --size "0" \
      --format "value(currentActions)" \
      --region "$REGION" \
      --quiet &>/dev/null

    # wait
    wait_until_instance_group_is_stable

    # ensure it's using the latest template/image
    gcloudrig_update_instance_group

    # and scale it back up again (chance of being spawned in a different zone)
    gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
      --size "1" \
      --format "value(currentActions)" \
      --region "$REGION" \
      --quiet &>/dev/null
  done

  # we have an instance!
  gcloudrig_set_running_instance_zone_bootdisk

  echo "To watch boot/setup progress, visit https://console.cloud.google.com/logs/viewer?project=$PROJECT_ID&advancedFilter=logName%3Dprojects%2F$PROJECT_ID%2Flogs%2Fgcloudrig-install"
}

# scale to 0 and wait
function gcloudrig_stop {
  echo "Stopping gcloudrig..."

  gcloud compute instances set-disk-auto-delete "$INSTANCE" \
    --zone "$ZONE" \
    --disk "$BOOTDISK" \
    --no-auto-delete

  gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
    --size "0" \
    --format "value(currentActions)" \
    --region "$REGION" \
    --quiet &>/dev/null

  wait_until_instance_group_is_stable
}

# turn boot disk into an image; delete all but latest on success
function gcloudrig_boot_disk_to_image {
  local images=()
  local newimage=""

  echo "Creating boot image, this may take some time..."

  # save boot image, but don't label it yet
  newimage="$BOOTDISK-$(date +"%Y%m%d%H%M%S")"
  gcloud compute images create "$newimage" \
    --source-disk "$BOOTDISK" \
    --source-disk-zone "$ZONE" \
    --guest-os-features "WINDOWS" \
    --family "$IMAGEFAMILY" \
    --storage-location "$REGION" \
    --labels "$GCRLABEL=true" \
    --quiet

  # find existing images
  mapfile -t images < <(gcloud compute images list \
    --format "value(name)" \
    --filter "labels.$GCRLABEL=true")

  # remove the "latest=true" label from all old images
  for image in "${images[@]}"; do
    LATEST="$(gcloud compute images describe "$image" \
      --format "value(labels.latest)")"
    if [ "$LATEST" = "true" ]; then
      gcloud compute images remove-labels "$image" \
        --labels "latest"
    fi
  done

  # add labels to the latest image
  gcloud compute images add-labels "$newimage" \
    --labels "latest=true,$GCRLABEL=true"

  # update the instance group (in the background)
  gcloudrig_update_instance_group &

  # delete boot disk
  gcloud compute disks delete "$BOOTDISK" \
    --zone "$ZONE" \
    --quiet

  # get all the images again, *except* the one labelled latest
  mapfile -t images < <(gcloud compute images list \
      --format "value(name)" \
      --filter "labels.$GCRLABEL=true NOT labels.latest=true")

  # delete them
  for image in "${images[@]}"; do
    gcloud compute images delete "$image" --quiet &
  done

  # wait for things to finish
  wait
}

# turn games disk into a snapshot; delete all but latest on success
function gcloudrig_games_disk_to_snapshot {
  local snapshots=()
  local newsnapshot=""

  echo "Snapshotting games disk..."

  # save games snapshot, but don't label it yet
  newsnapshot="$GAMESDISK-$(date +"%Y%m%d%H%M%S")"
  gcloud compute disks snapshot "$GAMESDISK" \
    --snapshot-names "$newsnapshot" \
    --zone "$ZONE" \
    --storage-location "$REGION" \
    --guest-flush \
    --quiet &>/dev/null

  # find existing snapshots
  mapfile -t snapshots < <(gcloud compute snapshots list \
    --format "value(name)" \
    --filter "labels.$GCRLABEL=true")

  # remove the "latest=true" label from all existing gcloudrig snapshots
  for snapshot in "${snapshots[@]}"; do
    LATEST="$(gcloud compute snapshots describe "$snapshot" \
      --format "value(labels.latest)")"
    if [ "$LATEST" = "true" ]; then
      gcloud compute snapshots remove-labels "$snapshot" \
        --labels "latest"
    fi
  done

  # add labels to the latest snapshot
  gcloud compute snapshots add-labels "$newsnapshot" \
    --labels "latest=true,$GCRLABEL=true"

  # delete games disk
  gcloud compute disks delete "$GAMESDISK" \
    --zone "$ZONE" \
    --quiet

  # get all the snapshots again, *except* the one labelled latest
  mapfile -t snapshots < <(gcloud compute snapshots list \
      --format "value(name)" \
      --filter "labels.$GCRLABEL=true NOT labels.latest=true")

  # delete them
  for snapshot in "${snapshots[@]}"; do
    gcloud compute snapshots delete "$snapshot" --quiet
  done
}

# mounts games disk, restoring from latest snapshot or creating a new one if nessessary
# no size/disk type specifified; gcloud will default to 500GB pd-standard when creating
function gcloudrig_mount_games_disk {
  local snapshot
  local existingdisk

  echo "Restoring/creating games disk..."
  
  # get latest games snapshot
  snapshot="$(gcloud compute snapshots list \
    --format "value(name)" \
    --filter "labels.$GCRLABEL=true labels.latest=true")"

  existingdisk="$(gcloud compute disks list \
    --filter "name=$GAMESDISK zone:($ZONE)" \
    --format "value(name)")"

  # create a blank games disk
  if [ -z "$snapshot" ] && [ -z "$existingdisk" ]; then
    gcloud compute disks create "$GAMESDISK" \
      --zone "$ZONE" \
      --quiet \
      --labels "$GCRLABEL=true"

  # or restore it from the latest snapshot
  elif [ -z "$existingdisk" ]; then
    gcloud compute disks create "$GAMESDISK" \
      --zone "$ZONE" \
      --source-snapshot "$snapshot" \
      --quiet \
      --labels "$GCRLABEL=true"
  fi

  # disk exists, attach it
  echo "Mounting games disk..."
  gcloud compute instances attach-disk "$INSTANCE" \
    --disk "$GAMESDISK" \
    --zone "$ZONE" \
    --quiet &>/dev/null
}


function gcloudrig_reset_windows_password {
  # to reset a password, we have to have a running instance
  gcloudrig_set_running_instance_zone_bootdisk

  if [ -z "$INSTANCE" ]; then
    echo "Could not find a running instance to issue a password reset; run ./scale-up.sh to start your rig then try this command again." >&2
    exit 1
  fi

  gcloud compute reset-windows-password "$INSTANCE" \
    --user "$WINDOWSUSER" \
    --zone "$ZONE" \
    --format "table[box,title='Windows Credentials'](ip_address,username,password)"
}