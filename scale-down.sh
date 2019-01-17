#!/usr/bin/env bash

# exit on error
set -e
[ -n "$GCLOUDRIG_DEBUG" ] && set -x

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_gcloudrig;

# shut it down
gcloudrig_stop

# save boot image
gcloudrig_boot_disk_to_image &

# save games snapshot
gcloudrig_games_disk_to_snapshot &

wait
