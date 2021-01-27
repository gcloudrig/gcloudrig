#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  destroy.sh                                            ###
###                                                        ###
###  invoking this script will attempt to delete all       ###
###  resources involved with gcloudrig; it's the nuclear   ###
###  option for when you want to blow it all away and      ###
###  start over again.                                     ###
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
source "$DIR/globals.sh"
##############################################################

init_gcloudrig;

# shut it down
gcloudrig_stop || echo -n

# delete managed instance group
gcloudrig_delete_instance_group 

# remove software install metadata
gcloud compute project-info remove-metadata \
  --keys "gcloudrig-setup-script-gcs-url,gcloudrig-setup-state,gcloudrig-setup-options" || echo -n

# remove software install script
gsutil rm "$GCSBUCKET/gcloudrig.psm1" || echo -n

# delete images
images=()
mapfile -t images < <(gcloud compute images list \
  --format "value(name)" \
  --filter "labels.$GCRLABEL=true")
for image in "${images[@]}"; do
  gcloud compute images delete "$image" || echo -n
done

# delete disks, if left behind
disks=()
mapfile -t disks < <(gcloud compute disks list \
  --filter="name:gcloudrig" \
  --format="csv[no-heading](name,zone)")
for name_zone in "${disks[@]}"; do
  name="${name_zone%%,*}"
  zone="${name_zone##*,}"
  gcloud compute disks delete "$name" \
    --zone "$zone" || echo -n
done

# delete snapshots
SNAPSHOTS=()
mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
  --format "value(name)" \
  --filter "labels.$GCRLABEL=true")
for SNAP in "${SNAPSHOTS[@]}"; do
  gcloud compute snapshots delete "$SNAP" || echo -n
done

# delete 'gcloud config configuration'
gcloud config configurations activate NONE || echo -n
gcloud config configurations delete "$CONFIGURATION" 
