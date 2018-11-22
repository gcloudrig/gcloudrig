#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_globals;

INSTANCE="$(gloudrig_get_instance_from_group "$REGION" "$INSTANCEGROUP")"

ZONE="$(gcloudrig_get_instance_zone_from_group "$REGION" "$INSTANCEGROUP")"

# set/reset windows credentials
gcloud compute reset-windows-password "$INSTANCE" \
	--user "$USER" \
	--zone "$ZONE" \
	--format "table[box,title='Windows Credentials'](ip_address,username,password)"
