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

OLD_REGION="$REGION"
echo
echo "Current region: $REGION"
gcloudrig_select_region

if [ "$REGION" != "$OLD_REGION" ] ; then
  init_common

  gcloudrig_delete_instance_group
  gcloudrig_create_instance_group
fi
