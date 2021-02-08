#!/usr/bin/env bash
# shellcheck disable=SC2034

##############################################################
###                   _             _     _                ###
###           __ _ __| |___ _  _ __| |_ _(_)__ _           ###
###          / _` / _| / _ \ || / _` | '_| / _` |          ###
###          \__, \__|_\___/\_,_\__,_|_| |_\__, |          ###
###          |___/                         |___/           ###
###                                                        ###
###  config.sh                                             ###
###                                                        ###
###  you shouldn't have to edit this unless you really     ###
###  want to - e.g. testing a different GPU or using your  ###
###  own custom image                                      ###
###                                                        ###
##############################################################

# What GPU would you like and how many? (See https://cloud.google.com/compute/docs/gpus)
ACCELERATORTYPE="nvidia-tesla-t4-vws"
ACCELERATORCOUNT="1"

# GCP Instance and Boot Disk type
# 12 vCPU; 32 GB RAM
INSTANCETYPE="n1-custom-12-32768"
BOOTTYPE="pd-ssd"

# do we make preemptible instances?
PREEMPTIBLE="true"

# GCP Base Image and Family (replace these if you're using your own custom image - give it a family name and enter the Project ID)
IMAGEBASEFAMILY="windows-2019"
IMAGEBASEPROJECT="windows-cloud"

# Various resource and label names
GCLOUDRIG_PREFIX="gcloudrig"                     # note: also used in gcloudrig-boot.ps1
GCRLABEL="${GCLOUDRIG_PREFIX}"                   # note: also used in gcloudrig-boot.ps1
GAMESDISK="${GCLOUDRIG_PREFIX}-games"            # note: also used in gcloudrig-boot.ps1
IMAGEFAMILY="${GCLOUDRIG_PREFIX}"
INSTANCEGROUP="${GCLOUDRIG_PREFIX}-group"
INSTANCENAME="${GCLOUDRIG_PREFIX}"
SETUPTEMPLATE="${GCLOUDRIG_PREFIX}-setup-template"
CONFIGURATION="${GCLOUDRIG_PREFIX}"
WINDOWSUSER="gcloudrig"

# other globals; overrides may be ignored
REGION=""
PROJECT_ID=""
ZONES=""
GCSBUCKET=""

# default setup options; these will also be selectable during ./setup.sh
declare -A SETUPOPTIONS
SETUPOPTIONS[ZeroTierNetwork]=""
SETUPOPTIONS[VideoMode]="1920x1080"
SETUPOPTIONS[DisplayScaling]=""
SETUPOPTIONS[InstallSteam]="false"
SETUPOPTIONS[InstallBattlenet]="false"
SETUPOPTIONS[InstallSSH]="false"
SETUPOPTIONS[InstallGoogleChrome]="false"
SETUPOPTIONS[InstallFirefox]="false"
