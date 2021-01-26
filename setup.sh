#!/usr/bin/env bash

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  setup.sh                                              ###
###                                                        ###
###  invoking this script will create (or recreate) an     ###
###  instance group and instance template and ask you a    ###
###  few questions about how you would like your rig       ###
###  customised.  you can re-run this at any time as long  ###
###  as your rig isn't running (or doesn't exist yet!).    ###
###  if you need to delete your instance and start again,  ###
###  see ./destroy.sh                                      ###
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

init_setup

echo
while read -r -n 1 -p "Would you like to automatically install some things? [y/n] " ; do
  case $REPLY in
    y|Y)
      echo
      gcloudrig_select_software_options
      gcloudrig_enable_software_setup
      break
      ;;
    n|N)
      echo
      break
      ;;
  esac
done

# create/recreate instance group; uses the startup template by default
gcloudrig_delete_instance_group
gcloudrig_create_instance_group

echo "Done!  Run './scale-up.sh' to start your instance.  If this is it's first launch, installations may take ~20mins to finish."
