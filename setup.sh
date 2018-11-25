#!/usr/bin/env bash

# exit on error
set -e

set -x

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_setup # init;

# create/recreate instance group and template
gcloudrig_delete_instance_group
gcloudrig_delete_instance_template
gcloudrig_create_instance_template
gcloudrig_create_instance_group

# create gcs bucket
GCSBUCKET="gs://$PROJECT_ID"

echo "Creating GCS bucket $GCSBUCKET/ to store install script..."
gsutil mb -p "$PROJECT_ID" -c regional -l "$REGION"  "$GCSBUCKET/" || echo "already exists?"

echo "Copying software install script to GCS..."
gsutil cp "$DIR/gcloudrig.psm1" "$GCSBUCKET/"

# replace any '#' chars, since they're used in sed command
# TODO: This is horribly insecure; migrate to `gcloud kms` instead?
WINDOWS_PASS="$(generate_windows_password | tr '#' '^')"

# create installation template and point group at it
echo "Creating setup template $SETUPTEMPLATE..."
gcloud compute instance-templates create "$SETUPTEMPLATE" \
    --accelerator "type=$ACCELERATORTYPE,count=$ACCELERATORCOUNT" \
    --boot-disk-type "$BOOTTYPE" \
    --image-family "$IMAGEBASEFAMILY" \
    --image-project "$IMAGEBASEPROJECT" \
    --labels "$GCRLABEL=true" \
    --machine-type "$INSTANCETYPE" \
    --maintenance-policy "TERMINATE" \
    --no-boot-disk-auto-delete \
    --no-restart-on-failure \
    --format "value(name)" \
    --metadata-from-file windows-startup-script-ps1=<(sed -e "s#@URL@#$GCSBUCKET/gcloudrig.psm1#;s#@PASSWORD@#$WINDOWS_PASS#" "$DIR/windows-setup.ps1.template") \
    --quiet

# point group at installation template
gcloud compute instance-groups managed "$INSTANCEGROUP" set-instance-template "$SETUPTEMPLATE"

# start 'er up
gcloudrig_start
gcloudrig_mount_games_disk

# wait until script is complete
logURL="https://console.cloud.google.com/logs/viewer?authuser=1&project=${PROJECT_ID}&resource=global&logName=projects%2F${PROJECT_ID}%2Flogs%2Fgcloudrig-install"
echo "Software install will take a while. Watch the logs at:"
echo
echo "  $logURL"
echo
echo "The last line will be 'All done!'"
echo
echo "To connect with RDP"
echo "  username: gcloudrig"
echo "  password: $WINDOWS_PASS"
read -r -p "Press enter when software install is complete..."

echo "Removing software install script from GCS..."
gsutil rm "$GCSBUCKET/gcloudrig.psm1"

# shut it down
gcloudrig_stop

# save boot image (in the background)
gcloudrig_boot_disk_to_image &

# save games snapshot (in the background)
gcloudrig_games_disk_to_snapshot &

# point managed instance group back at the real template
echo "Tidying up..."
gcloud compute instance-groups managed set-instance-template "$INSTANCEGROUP" \
    --template "$INSTANCETEMPLATE" \
    --region "$REGION" \
    --quiet

# delete setup template
gcloud compute instance-templates delete "$SETUPTEMPLATE" \
    --quiet

# wait for background tasks to complete
wait

echo "Done!  Run './scale-up.sh' to start your instance."
