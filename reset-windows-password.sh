#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  reset-windows-password.sh                             ###
###                                                        ###
###  if you forget your password or are like me and don't  ###
###  bother to remember it at all, run this to reset it.   ###
###  note you will have to provide the new password to     ###
###  autologin - once you remote in, update autologin via  ###
###  Start > Run > 'control userpasswords2' and toggle the ###
###  "Users require a password to login to this computer"  ###
###  checkbox.                                             ###
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
source "$DIR/globals.sh"
##############################################################

init_gcloudrig;

INSTANCE="$(gcloudrig_get_instance_from_group "$INSTANCEGROUP")"
ZONE="$(gcloudrig_get_instance_zone_from_group "$INSTANCEGROUP")"

# set/reset windows credentials
gcloudrig_reset_windows_password
