#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

# shut it down
echo "Stopping gcloudrig"
gcloudrig_stop

# save boot image
echo "Saving new boot image"
gcloudrig_boot_disk_to_image

# save games snapshot
echo "Snapshotting games disk"
gcloudrig_games_disk_to_snapshot