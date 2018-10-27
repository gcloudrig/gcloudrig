#!/usr/bin/env bash

# vars
PROJECT="gcloudrig"
REGION="us-west2"
IMAGE="gcloudrig"
INSTANCEGROUP="gcloudrig-group"
INSTANCETEMPLATE="gcloudrig-template"
GAMESDISK="gcloudrig-games"
BOOTSNAP="gcloudrig-snap"
GAMESSNAP="gcloudrig-games-snap"
INSTANCETYPE="n1-standard-8"
INSTANCEACCELERATOR="type=nvidia-tesla-p4-vws,count=1"
BOOTSIZE="50GB"
BOOTTYPE="pd-ssd"
IMAGEBASEPROJECT="windows-cloud"
IMAGEBASEFAMILY="windows-2016"

# config
gcloud config set project $PROJECT --quiet

# scale to 1 and wait
function gcloudrig_start {
	gcloud compute instance-groups managed resize $INSTANCEGROUP --size 1 --region $REGION --quiet
	gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP --region $REGION --quiet
	export INSTANCE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP --region $REGION --format "value(instance)" --quiet)
	export ZONE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP --region $REGION --format "value(instance.scope().segment(0))" --quiet)
	export BOOTDISK=$(gcloud compute instances describe $INSTANCE --zone $ZONE --format "value(disks[0].source.basename())" --quiet)
}

# scale to 0 and wait
function gcloudrig_stop {
	export INSTANCE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP --region $REGION --format "value(instance)" --quiet)
	export ZONE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP --region $REGION --format "value(instance.scope().segment(0))" --quiet)
	export BOOTDISK=$(gcloud compute instances describe $INSTANCE --zone $ZONE --format "value(disks[0].source.basename())" --quiet)
	gcloud compute instance-groups managed resize $INSTANCEGROUP --size 0 --region $REGION --quiet
	gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP --region $REGION --quiet
}