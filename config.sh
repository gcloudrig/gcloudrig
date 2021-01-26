#!/usr/bin/env bash
# shellcheck disable=SC2034

##########
# CONFIG #
##########

# What GPU would you like and how many? (See https://cloud.google.com/compute/docs/gpus)
ACCELERATORTYPE="nvidia-tesla-p4-vws"
ACCELERATORCOUNT="1"

# GCP Instance and Boot Disk type
INSTANCETYPE="n1-standard-8"
BOOTTYPE="pd-ssd"

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

declare -A SETUPOPTIONS
SETUPOPTIONS[ZeroTierNetwork]=""
SETUPOPTIONS[VideoMode]="1920x1080"
SETUPOPTIONS[DisplayScaling]=""
SETUPOPTIONS[InstallSteam]="false"
SETUPOPTIONS[InstallBattlenet]="false"
SETUPOPTIONS[InstallSSH]="false"
SETUPOPTIONS[InstallGoogleChrome]="false"
SETUPOPTIONS[InstallFirefox]="false"