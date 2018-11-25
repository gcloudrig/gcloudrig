#!/usr/bin/env bash

# what gpu and how many? see https://cloud.google.com/compute/docs/gpus
ACCELERATORTYPE="nvidia-tesla-p4-vws"
ACCELERATORCOUNT="1"

# instance and boot disk type?
INSTANCETYPE="n1-standard-8"
BOOTTYPE="pd-ssd"

# base image?
IMAGEBASEFAMILY="windows-2016"
IMAGEBASEPROJECT="windows-cloud"

# various resource and label names
GAMESDISK="gcloudrig-games"
GCRLABEL="gcloudrig"
IMAGEFAMILY="gcloudrig"
INSTANCEGROUP="gcloudrig-group"
INSTANCENAME="gcloudrig"
INSTANCETEMPLATE="gcloudrig-template"
CONFIGURATION="gcloudrig"

# override only if nessessary
REGION=""
PROJECT_ID=""
ZONES=""



########
# INIT #
########

# ensures sensible globals are set
function init_globals {

  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  fi

  if [ -z "$REGION" ]; then
    REGION="$(gcloud config get-value compute/region --quiet)"
  fi

  # if we still have a project id or region, bail and ask user to run setup
  if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
    [ -z "$PROJECT_ID" ] && echo "Missing config 'core/project'"
    [ -z "$REGION" ] && echo "Missing config 'compute/region'"
    echo "Please run './setup.sh' or 'gcloud init' to re-initialize the existing configuration, [$CONFIGURATION]."
    exit 1
  fi

  gcloudrig_set_vars
}

# ensures sensible globals are set; same as init_globals, but runs gcloud init if they're not set
function init_setup {
  # create/recreate configuration
  echo "Creating configuration '$CONFIGURATION'"
  gcloud config configurations create $CONFIGURATION --quiet &>/dev/null || echo -n
  gcloud config configurations activate $CONFIGURATION --quiet &>/dev/null

  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  fi

  if [ -z "$REGION" ]; then
    REGION="$(gcloud config get-value compute/region --quiet)"
  fi

  # check if default project is set; if not, run 'gcloud init'
  if [ -z "$PROJECT_ID" ]; then
    gcloud init
    PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  fi

  # check if compute api is enabled, if not enable it
  COMPUTEAPI=$(gcloud services list --format "value(config.name)" --filter "config.name=compute.googleapis.com" --quiet)
  if [ "$COMPUTEAPI" != "compute.googleapis.com" ]; then
    echo "Enabling Compute API..."
    gcloud services enable compute.googleapis.com
  fi

  # check if a default region is set, if not re-run 'gcloud init'
  if  [ -z "$REGION" ]; then
    gcloud init --skip-diagnostics
  fi

  # now set the zones
  gcloudrig_set_vars;
}



###########
# SETTERS #
###########

# Populate $ZONES with any zones that has the accelerator 
# resources in the $REGION we're after
function gcloudrig_set_vars {
  local groupsize=0
  local regionzones=()
  local acceleratorzones=()

  # get a list of zones in this region
  mapfile -d ";" -t regionzones < <(gcloud compute regions describe "$REGION" \
    --format="value(zones)")

  # get a list of zones with accelerators
  mapfile -d ";" -t acceleratorzones < <(gcloud compute accelerator-types list \
    --filter "name=$ACCELERATORTYPE" \
    --format "value(zone)")

  # intersection
  for zoneuri in "${regionzones[@]}"; do
    local zone=""
    zone="$(basename -- "$zoneuri")"
    if [[ ${acceleratorzones[*]} =~ $zone ]]; then
      ZONES="${ZONES},${zone}"
    fi;
  done

  # expose a list of zones in this region that support the given accelerator type
  ZONES="${ZONES:1}"

  # get the number of instances currently running
  groupsize=$(gcloud compute instance-groups describe "$INSTANCEGROUP" --format "value(size)" --region "$REGION" --quiet || echo "0")

  # if an instance is running, expose some more vars
  if [ "$groupsize" -gt "0" ]; then
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
    --filter "labels.gcloudrig=true labels.latest=true"
}



############
# COMMANDS #
############

function wait_until_instance_group_is_stable {
  timeout 120s gcloud compute instance-groups managed wait-until-stable "$INSTANCEGROUP" \
  	--region "$REGION" \
    --quiet

  err=$?

  if [ "$err" -gt "0" ]; then
    gcloud logging read 'severity>=WARNING' \
      --freshness 10m \
      --format "table[box,title='-- Recent logs (10m) --'](timestamp,protoPayload.status.message)"
    return $err
  fi
}

# scale to 1 and wait, with retries every 5 minutes
function gcloudrig_start {
  echo "Starting gcloudrig..."

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

    # and back up again (chance of being spawned in a different zone)
    gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
      --size "1" \
      --format "value(currentActions)" \
      --region "$REGION" \
      --quiet &>/dev/null
  done

  # we have an instance!
  INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
  ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"
  BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"
}

# scale to 0 and wait
function gcloudrig_stop {
  echo "Stopping gcloudrig..."

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
  newimage="$IMAGEFAMILY-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')"
  gcloud compute images create "$newimage" \
    --source-disk "$BOOTDISK" \
    --source-disk-zone "$ZONE" \
    --guest-os-features "WINDOWS" \
    --family "$IMAGEFAMILY" \
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
    gcloud compute images delete "$image" --quiet
  done
}

# turn games disk into a snapshot; delete all but latest on success
function gcloudrig_games_disk_to_snapshot {
  local snapshots=()
  local newsnapshot=""

  echo "Snapshotting games disk..."

  # save games snapshot, but don't label it yet
  newsnapshot="$GAMESDISK-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')-snap"
  gcloud compute disks snapshot "$GAMESDISK" \
    --snapshot-names "$newsnapshot" \
    --zone "$ZONE" \
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
    --filter "labels.gcloudrig=true labels.latest=true")"

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