#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals 
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# start it up
echo "Starting gcloudrig"
gcloudrig_start

# mount games disk
echo "Mounting games disk"
gcloudrig_mount_games_disk
