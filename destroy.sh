#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $DIR/globals.sh

# shut it down
gcloudrig_stop || sleep 1

# delete managed instance group
gcloud compute instance-groups managed delete $INSTANCEGROUP --region $REGION  || sleep 1

# delete instance templates
gcloud compute instance-templates delete $INSTANCETEMPLATE-base  || sleep 1
gcloud compute instance-templates delete $INSTANCETEMPLATE  || sleep 1

# delete snapshots
gcloud compute snapshots delete $BOOTSNAP || sleep 1
gcloud compute snapshots delete $GAMESSNAP  || sleep 1

# delete disks
gcloud compute disks delete $GAMESDISK --zone $ZONE || sleep 1
gcloud compute disks delete $BOOTDISK --zone $ZONE || sleep 1

# delete image
gcloud compute images delete $IMAGE  || sleep 1