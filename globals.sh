#!/usr/bin/env bash

# gcloudrig/globals.sh

# region and project?
REGION="us-west2"
PROJECT="gcloudrig"

# instance and boot disk type?
INSTANCETYPE="n1-standard-8"
BOOTTYPE="pd-ssd"

# what gpu and how many? see https://cloud.google.com/compute/docs/gpus
ACCELERATORTYPE="nvidia-tesla-p4-vws"
ACCELERATORCOUNT="1"

# base image?
IMAGEBASEFAMILY="windows-2016"
IMAGEBASEPROJECT="windows-cloud"

# various resource and label names
GAMESDISK="gcloudrig-games"
DISKLABEL="gcloudrig"
IMAGE="gcloudrig"
INSTANCEGROUP="gcloudrig-group"
INSTANCENAME="gcloudrig"
INSTANCETEMPLATE="gcloudrig-template"

# config
gcloud config set project $PROJECT \
	--quiet

# returns 
function array_contains () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

# Populate $ZONES with any zones that has the accelerator resources we're after in the $REGION we want
function gcloudrig_set_zones {
	OLDIFS=$IFS
	IFS=";"
	ZONES=""
	ACCELERATORZONES=($(gcloud compute accelerator-types list --filter "name=$ACCELERATORTYPE" --format "value(zone)"))
	for ZONEURI in $(gcloud compute regions describe $REGION --format="value(zones)"); do
		local ZONE=$(basename $ZONEURI)
		if [[ "${ACCELERATORZONES[@]}" =~ "$ZONE" ]]; then
			ZONES=${ZONES},${ZONE}
		fi;
	done
	IFS=$OLDIFS
	ZONES=${ZONES:1}
}

# scale to 1
function gcloudrig_start {

	# scale to 1
	gcloud compute instance-groups managed resize $INSTANCEGROUP \
		--size 1 \
		--region $REGION \
		--format "value(currentActions)" \
		--quiet

	# wait 90s for the group to be stable, then scale down/up and try again
	# some regions seem 'unofficially' have vws gpus (e.g. australia-southeast1) but not much capacity
	# this *seems* to make our request bounce around until we land on a zone that has capacity at the point we ask for it
	# which *seems* to be faster on average than just leaving it alone and, well, "waiting till stable".
	while ! timeout 90 gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP --region $REGION --quiet; do
		gcloud compute instance-groups managed resize $INSTANCEGROUP \
			--size 0 \
			--region $REGION \
			--format "value(currentActions)" \
			--quiet
		gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP --region $REGION --quiet
		gcloud compute instance-groups managed resize $INSTANCEGROUP \
			--size 1 \
			--region $REGION \
			--format "value(currentActions)" \
			--quiet
	done

	INSTANCE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP \
		--region $REGION \
		--format "value(instance)" \
		--quiet \
	)

	ZONE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP \
		--region $REGION \
		--format "value(instance.scope().segment(0))" \
		--quiet \
	)

	BOOTDISK=$(gcloud compute instances describe $INSTANCE \
		--zone $ZONE \
		--format "value(disks[0].source.basename())" \
		--quiet \
	)

}

# scale to 0 and wait
function gcloudrig_stop {

	INSTANCE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP \
		--region $REGION \
		--format "value(instance)" \
		--quiet \
	)

	ZONE=$(gcloud compute instance-groups list-instances $INSTANCEGROUP \
		--region $REGION \
		--format "value(instance.scope().segment(0))" \
		--quiet \
	)

	BOOTDISK=$(gcloud compute instances describe $INSTANCE \
		--zone $ZONE \
		--format "value(disks[0].source.basename())" \
		--quiet \
	)

	gcloud compute instance-groups managed resize $INSTANCEGROUP \
		--size 0 \
		--region $REGION \
		--quiet

	gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP \
		--region $REGION \
		--quiet

}


# turn boot disk into an image
function gcloudrig_boot_disk_to_image {

	echo "Creating boot image, this may take some time..."

	# delete existing boot image
	gcloud compute images delete $IMAGE \
		--quiet || echo "assuming $IMAGE doesn't exist, continuing..."

	# create boot image from boot disk
	gcloud compute images create $IMAGE \
		--source-disk $BOOTDISK \
		--source-disk-zone $ZONE \
		--guest-os-features WINDOWS \
		--quiet

	# delete boot disk
	gcloud compute disks delete $BOOTDISK \
		--zone $ZONE \
		--quiet

}

# turn games disk into a snapshot
function gcloudrig_games_disk_to_snapshot {

	# save games snapshot
	GAMESSNAP="$GAMESDISK-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')-snap"
	gcloud compute disks snapshot $GAMESDISK \
		--snapshot-names $GAMESSNAP \
		--zone $ZONE \
		--guest-flush \
		--quiet

	# remove the "latest=true" label from any existing gcloudrig snapshots
	for SNAP in $(gcloud compute snapshots list --format "value(name)" --filter "labels.$DISKLABEL=true"); do
		LATEST=$(gcloud compute snapshots describe $SNAP --format "value(labels.latest)")
		if [ $LATEST = "true" ]; then
			gcloud compute snapshots remove-labels $SNAP --labels "latest"
		fi
	done

	# add labels to the latest snapshot
	gcloud compute snapshots add-labels $GAMESSNAP --labels "latest=true,$DISKLABEL=true"

	# delete games disk
	gcloud compute disks delete $GAMESDISK \
		--zone $ZONE \
		--quiet || echo "assuming $GAMESDISK is still in use, continuing..."

}

# mounts games disk, restoring from latest snapshot or creating a new one if nessessary
# no size/disk type specifified; gcloud will default to 500GB pd-standard when creating
function gcloudrig_mount_games_disk {

	# get latest games snapshot
	GAMESSNAP=$(gcloud compute snapshots list --format "value(name)" --filter "labels.gcloudrig=true labels.latest=true")

	# restore games snapshot
	# or create a new games disk
	# or just keep going and assume a games disk already exists
	gcloud compute disks create $GAMESDISK \
		--zone $ZONE \
		--source-snapshot $GAMESSNAP \
		--quiet \
	|| gcloud compute disks create $GAMESDISK \
		--zone $ZONE \
		--quiet \
	|| echo "assuming $GAMESDISK exists, continuing..."

	# attach games disk
	gcloud compute instances attach-disk $INSTANCE \
		--disk $GAMESDISK \
		--zone $ZONE \
		--quiet

}