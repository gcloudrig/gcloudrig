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

# # create/recreate instance group; uses the startup template by default
gcloudrig_delete_instance_group
gcloudrig_create_instance_group

OPTIONS="Yes No"
echo "Would you like to automatically install some things?"
select opt in $OPTIONS; do
    if [ "$opt" == "Yes" ]; then
        # create GCS bucket and upload script
        echo "Creating GCS bucket $GCSBUCKET/ to store install script..."
        gsutil mb -p "$PROJECT_ID" -c regional -l "$REGION"  "$GCSBUCKET/" || echo "already exists?"

        echo "Copying software install script to GCS..."
        gsutil cp "$DIR/gcloudrig.psm1" "$GCSBUCKET/"

        # announce script's gcs url via project metadata
        gcloud compute project-info add-metadata --metadata "gcloudrig-setup-script-gcs-url=$GCSBUCKET/gcloudrig.psm1" --quiet

        # start 'er up
        gcloudrig_start
        gcloudrig_mount_games_disk

        # wait until script is complete
        logURL="https://console.cloud.google.com/logs/viewer?authuser=1&project=${PROJECT_ID}&resource=global&logName=projects%2F${PROJECT_ID}%2Flogs%2Fgcloudrig-install"
        echo "Software install will take a while. Watch the logs at:"
        echo
        echo "  $logURL"
        echo
        read -r -p "Press enter when software install is complete..."

        echo "Removing software install script from GCS..."
        gsutil rm "$GCSBUCKET/gcloudrig.psm1"

        # announce script's gcs url via project metadata
        gcloud compute project-info remove-metadata --keys "gcloudrig-setup-script-gcs-url,gcloudrig-setup-script-finished" --quiet

        # shut it down
        gcloudrig_stop

        # save boot image (in the background)
        gcloudrig_boot_disk_to_image &

        # save games snapshot (in the background)
        gcloudrig_games_disk_to_snapshot &

        # wait for background tasks to complete
        wait
    elif [ "$opt" == "No" ]; then
        break
    fi
done

echo "Done!  Run './scale-up.sh' to start your instance."
