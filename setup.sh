#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals 
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# create/recreate base instance template
echo "Creating instance template $INSTANCETEMPLATE-base using latest $IMAGEBASEFAMILY image..."
gcloud beta compute instance-templates delete "${INSTANCETEMPLATE}-base" --quiet || echo
gcloud beta compute instance-templates create "${INSTANCETEMPLATE}-base" \
	--image-family "$IMAGEBASEFAMILY" \
	--image-project "$IMAGEBASEPROJECT" \
	--machine-type "$INSTANCETYPE" \
	--accelerator "type=$ACCELERATORTYPE,count=$ACCELERATORCOUNT" \
	--boot-disk-type "$BOOTTYPE" \
	--maintenance-policy "TERMINATE" \
	--no-boot-disk-auto-delete \
	--no-restart-on-failure \
	--labels "$GCRLABEL=true" \
	--format "value(name)" \
	--quiet

# create a managed instance group that covers all zones (GPUs tend to be oversubscribed in certain zones)
# and give it the base instance template
echo "Creating managed instance group $INSTANCEGROUP..."
gcloud beta compute instance-groups managed delete "$INSTANCEGROUP" --quiet \
	--region "$REGION" \
	--zones "$ZONES" \
	|| echo
gcloud beta compute instance-groups managed create "$INSTANCEGROUP" \
	--base-instance-name "$INSTANCENAME" \
	--template "${INSTANCETEMPLATE}-base" \
	--size "0" \
	--region "$REGION" \
	--zones "$ZONES" \
	--format "value(name)" \
	--quiet

# run first-boot things, only if an image doesn't already exist
if ! gcloud compute images describe "$IMAGE" --format "value(name)"; then

	# turn it on
	echo "Starting gcloudrig..."
	gcloudrig_start

	# add extra volume
	echo "Mounting games disk..."
	gcloudrig_mount_games_disk

	# wait for 60 seconds.  
	# in future, this is where we should poll a URL or wait for a pub/sub to let us know software installation is complete.
	echo "Waiting 60 seconds for instance to settle..."
	sleep "60"

	# shut it down
	echo "Stopping gcloudrig..."
	gcloudrig_stop

	# save boot image
	echo "Saving new boot image..."
	gcloudrig_boot_disk_to_image

	# save games snapshot
	echo "Snapshotting games disk..."
	gcloudrig_games_disk_to_snapshot

fi

# create actual instance template
echo "Creating instance template $INSTANCETEMPLATE..."
gcloud beta compute instance-templates delete "$INSTANCETEMPLATE" --quiet || echo
gcloud beta compute instance-templates create "$INSTANCETEMPLATE" \
	--image "$IMAGE" \
	--machine-type "$INSTANCETYPE" \
	--accelerator "type=$ACCELERATORTYPE,count=$ACCELERATORCOUNT" \
	--boot-disk-type "$BOOTTYPE" \
	--maintenance-policy "TERMINATE" \
	--no-boot-disk-auto-delete \
	--no-restart-on-failure \
	--labels "$GCRLABEL=true" \
	--quiet

# point managed instance group at new template
echo "Tidying up..."
gcloud compute instance-groups managed set-instance-template "$INSTANCEGROUP" \
	--template "$INSTANCETEMPLATE" \
	--region "$REGION" \
	--quiet

# delete base template
gcloud compute instance-templates delete "${INSTANCETEMPLATE}-base" \
	--quiet

echo "Done!"
