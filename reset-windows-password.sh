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

INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"

# set/reset windows credentials
gcloudrig_reset_windows_password
