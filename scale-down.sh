#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  scale-down.sh                                         ###
###                                                        ###
###  invoking this script will scale the instance-group    ###
###  created during setup to 0, effectively shutting down  ###
###  your rig.  once that's done, it packs away the boot   ###
###  disk and games disk into cheaper storage.             ###
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
pushd "$DIR" || exit
source "globals.sh"; popd
##############################################################

init_gcloudrig;

# shut it down
gcloudrig_stop

# save boot image
gcloudrig_boot_disk_to_image &

# save games snapshot
gcloudrig_games_disk_to_snapshot &

wait
