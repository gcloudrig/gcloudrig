#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals 
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# create managed instance group e.g. if this is a new region
echo "Checking/Creating managed instance group $INSTANCEGROUP..."
	gcloud beta compute instance-groups managed describe "$INSTANCEGROUP" --region "$REGION" || \
	gcloud beta compute instance-groups managed create "$INSTANCEGROUP" \
		--base-instance-name "$INSTANCENAME" \
		--template "$INSTANCETEMPLATE" \
		--size 0 \
		--region "$REGION" \
		--zones "$ZONES" \
		--format "value(name)" \
		--quiet

# start it up
echo "Starting gcloudrig"
gcloudrig_start

# mount games disk
echo "Mounting games disk"
gcloudrig_mount_games_disk
