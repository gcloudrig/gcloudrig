#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals 
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# shut it down
echo "Stopping gcloudrig"
gcloudrig_stop

# save boot image
echo "Saving new boot image"
gcloudrig_boot_disk_to_image & 

# save games snapshot
echo "Snapshotting games disk"
gcloudrig_games_disk_to_snapshot & 

wait
