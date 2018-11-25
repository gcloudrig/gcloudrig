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

gcloudrig_delete_instance_group

gcloudrig_delete_instance_template

gcloudrig_create_base_image

gcloudrig_create_instance_template

gcloudrig_create_instance_group

echo "Done!  Run './scale-up.sh' to start your instance."
