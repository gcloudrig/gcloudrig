#!/usr/bin/env bash
#
# 

# exit on error
set -e
[ -n "$GCLOUDRIG_DEBUG" ] && set -x

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_gcloudrig;

echo
echo "Project ID:   $PROJECT_ID"
echo "Region:       $REGION"
echo

# get the number of instances currently running
groupsize=$(gcloud compute instance-groups list --filter "name=$INSTANCEGROUP region:($REGION)" --format "value(size)" --quiet || echo "0")

if [ "${groupsize:-0}" -gt 0 ]; then
  gcloudrig_get_instance_from_group "$INSTANCEGROUP"
  INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
  ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"
  BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"
  # TODO check for attached games disk 
  echo "$INSTANCE is running in $ZONE, booting from $BOOTDISK"
else
  echo "no running instance"

  instanceTemplate="$(gcloud compute instance-groups managed describe "$INSTANCEGROUP" --region "$REGION" --format="value(instanceTemplate)" --quiet)"
  if [ -n "$instanceTemplate" ] ; then
    templateProps="$(gcloud compute instance-templates describe \
      "$instanceTemplate" --quiet \
      --format="csv[no-heading](properties.disks.initializeParams.sourceImage,properties.guestAccelerators.acceleratorType)")"
    tmplBootImage="${templateProps%%,*}"
    tmplBootImage="${tmplBootImage##*/}"
    tmplGPU="${templateProps##*,}"

    echo "current configuration is:"
    echo
    echo "Instance group: $INSTANCEGROUP"
    echo "      template: ${instanceTemplate##*/}"
    echo
    echo "    boot image: $tmplBootImage"
    echo "           GPU: $tmplGPU"
    echo
  fi
  
  # check for games disk snapshots
  gamesDiskSnapshot="$(gcloud compute snapshots list  --format "value(name)" --filter "labels.$GCRLABEL=true labels.latest=true" --quiet)"
  if [ -n "$gamesDiskSnapshot" ] ; then
    echo "    Games disk"
    echo "      snapshot: $gamesDiskSnapshot"
  fi
fi

