#!/usr/bin/env bash

# gcloudrig/scale-up.sh

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

# start it up
echo "Starting gcloudrig"
gcloudrig_start

# mount games disk
echo "Mounting games disk"
gcloudrig_mount_games_disk