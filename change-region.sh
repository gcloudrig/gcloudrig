#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  change-region.sh                                      ###
###                                                        ###
###  invoking this script will recreate your instance      ###
###  group in a new GCP region.  note that cross-region    ###
###  egress costs apply; it may be easier to just delete   ###
###  everything and start again!                           ###
###                                                        ###
##############################################################
# bash "what directory am i" dance
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source "globals.sh"
##############################################################

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
