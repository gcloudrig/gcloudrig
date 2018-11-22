#!/usr/bin/env bash

# region and project
REGION=""
PROJECT_ID=""

# instance and boot disk type?
INSTANCETYPE="n1-standard-8"
BOOTTYPE="pd-ssd"

# what gpu and how many? see https://cloud.google.com/compute/docs/gpus
ACCELERATORTYPE="nvidia-tesla-p4-vws"
ACCELERATORCOUNT="1"

# base image?
IMAGEBASEFAMILY="windows-2016"
IMAGEBASEPROJECT="windows-cloud"

# various resource and label names
GAMESDISK="gcloudrig-games"
GCRLABEL="gcloudrig"
IMAGE="gcloudrig"
INSTANCEGROUP="gcloudrig"
INSTANCENAME="gcloudrig"
INSTANCETEMPLATE="gcloudrig"
CONFIGURATION="gcloudrig"

# sensible globals
function init_globals {

  PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  REGION="$(gcloud config get-value compute/region --quiet)"

  # if we don't have a project id or region, bail and ask user to run "gcloud init"

  if [ -z "$PROJECT_ID" ]; then
    echo "Unable to read config for 'core/project'!"
    echo
    echo "Please run 'gcloud init' followed by './setup.sh' to re-initialize the existing configuration, [$CONFIGURATION]."
    exit 1
  fi

  if [ -z "$REGION" ]; then
    echo "Unable to read config for 'compute/region'!"
    echo
    echo "Please run './setup.sh' to re-initialize the existing configuration, [$CONFIGURATION]."
  fi

  # set zones for this region
  gcloudrig_set_zones
}

# same as init_globals, but run during setup
function init_setup {
  # create/recreate configuration
  echo "Creating configuration '$CONFIGURATION'"
  gcloud config configurations create $CONFIGURATION --quiet &>/dev/null || echo -n
  gcloud config configurations activate $CONFIGURATION --quiet

  # check if default project is set;  if not, run 'gcloud init'
  PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  if [ -z "$PROJECT_ID" ]; then
    gcloud init
    PROJECT_ID="$(gcloud config get-value core/project --quiet)"
  fi

  # check if compute api is enabled, if not enable it
  COMPUTEAPI=$(gcloud services list --format "value(config.name)" --filter "config.name=compute.googleapis.com" --quiet)
  if [ $COMPUTEAPI != "compute.googleapis.com" ]; then
    echo "Enabling Compute API..."
    gcloud services enable compute.googleapis.com
  fi

  # check if a default region is set, if not re-run 'gcloud init'
  REGION="$(gcloud config get-value compute/region --quiet)"
  if  [ -z "$REGION" ]; then
    gcloud init --skip-diagnostics
  else
    echo "Re-run 'gcloud init' to select the default zone and region?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) gcloud init --skip-diagnostics; break;;
            No ) echo "Skipping 'gcloud init' re-run!"; break;;
        esac
    done
  fi

  # now set the zones
  gcloudrig_set_zones;
}

# Populate $ZONES with any zones that has the accelerator resources we're after in the $REGION we want
function gcloudrig_set_zones {
  ZONES=""

  local REGIONZONES=()
  mapfile -d ";" -t REGIONZONES < <(gcloud compute regions describe "$REGION" \
    --format="value(zones)")

  local ACCELERATORZONES=()
  mapfile -d ";" -t ACCELERATORZONES < <(gcloud compute accelerator-types list \
    --filter "name=$ACCELERATORTYPE" \
    --format "value(zone)")

  for ZONEURI in "${REGIONZONES[@]}"; do
    local ZONE=""
    ZONE="$(basename -- "$ZONEURI")"
    if [[ ${ACCELERATORZONES[*]} =~ $ZONE ]]; then
      ZONES="${ZONES},${ZONE}"
    fi;
  done

  ZONES="${ZONES:1}"
}

# Get instance name from instance group
function gcloudrig_get_instance_from_group {
  local instance_group="$1"
  gcloud compute instance-groups list-instances "$instance_group" \
  --format "value(instance)" \
  --quiet

}

# Get instance zone from instance group
function gcloudrig_get_instance_zone_from_group {
  local instance_group="$1"
  gcloud compute instance-groups list-instances "$instance_group" \
  --format "value(instance.scope().segment(0))" \
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

function wait_until_instance_group_is_stable {
  timeout 120s gcloud compute instance-groups managed wait-until-stable "$INSTANCEGROUP" \
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
    --quiet &>/dev/null

  # if it doesn't start in 5 minutes
  while ! wait_until_instance_group_is_stable; do

    # scale it back down
    gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
      --size "0" \
      --format "value(currentActions)" \
      --quiet &>/dev/null

    # wait
    wait_until_instance_group_is_stable

    # and back up again (chance of being spawned in a different zone)
    gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
      --size "1" \
      --format "value(currentActions)" \
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

  INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
  ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"
  BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"

  gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
    --size "0" \
    --format "value(currentActions)" \
    --quiet &>/dev/null

  wait_until_instance_group_is_stable

}

# turn boot disk into an image
function gcloudrig_boot_disk_to_image {

  echo "Creating boot image, this may take some time..."

  # delete existing boot image
  gcloud compute images delete "$IMAGE" --quiet &>/dev/null || echo

  # create boot image from boot disk
  gcloud compute images create "$IMAGE" \
    --source-disk "$BOOTDISK" \
    --source-disk-zone "$ZONE" \
    --guest-os-features WINDOWS \
    --labels "$GCRLABEL=true" \
    --quiet

  # delete boot disk
  gcloud compute disks delete "$BOOTDISK" \
    --zone "$ZONE" \
    --quiet

}

# turn games disk into a snapshot
function gcloudrig_games_disk_to_snapshot {

  echo "Snapshotting games disk..."

  # save games snapshot, but don't label it yet
  GAMESSNAP="$GAMESDISK-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')-snap"
  gcloud compute disks snapshot "$GAMESDISK" \
    --snapshot-names "$GAMESSNAP" \
    --zone "$ZONE" \
    --guest-flush \
    --quiet

  # find existing snapshots
  local SNAPSHOTS=()
  mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
      --format "value(name)" \
    --filter "labels.$GCRLABEL=true")

  # remove the "latest=true" label from all existing gcloudrig snapshots
  for SNAP in "${SNAPSHOTS[@]}"; do
    LATEST="$(gcloud compute snapshots describe "$SNAP" \
      --format "value(labels.latest)")"
    if [ "$LATEST" = "true" ]; then
      gcloud compute snapshots remove-labels "$SNAP" \
        --labels "latest"
    fi
  done

  # add labels to the latest snapshot
  gcloud compute snapshots add-labels "$GAMESSNAP" \
    --labels "latest=true,$GCRLABEL=true"

  # delete games disk
  gcloud compute disks delete "$GAMESDISK" \
    --zone "$ZONE" \
    --quiet

  # get all the snapshots again, *except* the one labelled latest
  mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
      --format "value(name)" \
      --filter "labels.$GCRLABEL=true NOT labels.latest=true")

  # delete them
  for SNAP in "${SNAPSHOTS[@]}"; do
    gcloud compute snapshots delete --quiet
  done

}

# mounts games disk, restoring from latest snapshot or creating a new one if nessessary
# no size/disk type specifified; gcloud will default to 500GB pd-standard when creating
function gcloudrig_mount_games_disk {

  echo "Mounting games disk..."

  # get latest games snapshot
  GAMESSNAP="$(gcloud compute snapshots list \
    --format "value(name)" \
    --filter "labels.gcloudrig=true labels.latest=true")"

  # restore games snapshot
  # or create a new games disk
  # or just keep going and assume a games disk already exists
  gcloud compute disks create "$GAMESDISK" \
    --zone "$ZONE" \
    --source-snapshot "$GAMESSNAP" \
    --quiet \
    --labels "$GCRLABEL=true" &>/dev/null \
    || gcloud compute disks create "$GAMESDISK" \
      --zone "$ZONE" \
      --quiet \
      --labels "$GCRLABEL=true" &>/dev/null \
      || echo "assuming $GAMESDISK exists, continuing..."

  # attach games disk
  gcloud compute instances attach-disk "$INSTANCE" \
  --disk "$GAMESDISK" \
  --zone "$ZONE" \
  --quiet &>/dev/null

}
