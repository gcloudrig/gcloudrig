#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals 
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# shut it down
gcloudrig_stop || echo .

# delete managed instance group
gcloud compute instance-groups managed delete "$INSTANCEGROUP" --region "$REGION" --quiet || echo .

# delete instance templates
gcloud compute instance-templates delete "$INSTANCETEMPLATE-base" --quiet || echo .
gcloud compute instance-templates delete "$INSTANCETEMPLATE" --quiet || echo .

# delete disks
gcloud compute disks delete "$GAMESDISK" --zone "$ZONE" --quiet || echo .
gcloud compute disks delete "$BOOTDISK" --zone "$ZONE" --quiet || echo .

# delete image
gcloud compute images delete $IMAGE --quiet || echo .