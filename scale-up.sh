#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  scale-up.sh                                           ###
###                                                        ###
###  invoking this script will scale the instance-group    ###
###  created during setup to 1 instance, wait till it's    ###
###  "stable" then exit.                                   ###
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
# shellcheck source=./globals.sh
source "$DIR/globals.sh"
##############################################################

init_gcloudrig;

# start it up
gcloudrig_start
