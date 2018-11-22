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

# create/recreate actual instance template
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

# create a managed instance group that covers all zones (GPUs tend to be oversubscribed in certain zones)
# and give it the base instance template
echo "Creating managed instance group $INSTANCEGROUP..."
gcloud beta compute instance-groups managed delete "$INSTANCEGROUP" --quiet \
	--region "$REGION" \
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

  echo "Creating GCS bucket $GCSBUCKET/ to store install script..."
  gsutil mb -p "$PROJECT_ID" -c regional -l "$REGION"  "$GCSBUCKET/" || echo "already exists?"

  echo "Copying software install script to GCS..."
  gsutil cp "$DIR/gcloudrig.psm1" "$GCSBUCKET/"

  # replace any '#' chars, messes with the sed command
  WINDOWS_PASS="$(generate_windows_password | tr '#' '^')"
  echo "Enabling software installer..." 
  gcloud compute project-info add-metadata \
    --metadata-from-file windows-startup-script-ps1=<(cat "$DIR/windows-setup.ps1.template" | \
    sed -e "s#@URL@#$GCSBUCKET/gcloudrig.psm1#;s#@PASSWORD@#$WINDOWS_PASS#")

	# turn it on
	echo "Starting gcloudrig..."
	gcloudrig_start

	# add extra volume
	echo "Mounting games disk..."
	gcloudrig_mount_games_disk

	# wait for 60 seconds.  
	# in future, this is where we should poll a URL or wait for a pub/sub to let us know software installation is complete.
  logURL="https://console.cloud.google.com/logs/viewer?authuser=1&project=${PROJECT_ID}&resource=global&logName=projects%2F${PROJECT_ID}%2Flogs%2Fgcloudrig-install"
  echo "Software install will take a while. Watch the logs at:"
  echo "$logURL"
  echo "The last line will be 'All done!'"
  echo
  echo "To connect with RDP"
  echo "  username: gcloudrig"
  echo "  password: $WINDOWS_PASS"
  read -p "Press enter when software install is complete..."

  echo "Disabling software installer..."
  gcloud compute project-info remove-metadata \
    --keys=windows-startup-script-ps1

  echo "Removing software install script from GCS..."
  gsutil rm "$GCSBUCKET/gcloudrig.psm1"

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
