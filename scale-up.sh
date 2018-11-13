#!/usr/bin/env bash

# gcloudrig/scale-up.sh

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

# create managed instance group e.g. if this is a new region
echo "Checking/Creating managed instance group $INSTANCEGROUP..."
	gcloud beta compute instance-groups managed describe $INSTANCEGROUP --region $REGION || \
	gcloud beta compute instance-groups managed create $INSTANCEGROUP \
		--base-instance-name $INSTANCENAME \
		--template $INSTANCETEMPLATE \
		--size 0 \
		--region $REGION \
		--zones $ZONES \
		--format "value(name)" \
		--quiet

# start it up
echo "Starting gcloudrig"
gcloudrig_start

# mount games disk
echo "Mounting games disk"
gcloudrig_mount_games_disk
