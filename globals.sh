#!/usr/bin/env bash

# vars
BOOTSIZE="50GB"
BOOTSNAP="test-gcloudrig-snap"
BOOTTYPE="pd-ssd"
GAMESDISK="test-gcloudrig-games"
IMAGE="test-gcloudrig"
IMAGEBASEFAMILY="windows-2016"
IMAGEBASEPROJECT="windows-cloud"
INSTANCEACCELERATOR="type=nvidia-tesla-p4-vws,count=1"
INSTANCEGROUP="test-gcloudrig-group"
INSTANCENAME="test-gcloudrig"
INSTANCETEMPLATE="test-gcloudrig-template"
INSTANCETYPE="n1-standard-8"
PROJECT="gcloudrig"
DISKLABEL="test-gcloudrig"
# REGION="australia-southeast1"
REGION="us-west2"

# config
gcloud config set project $PROJECT \
	--quiet

function gcloudrig_set_zones {
	# what zones are available in our region?
	OLDIFS=$IFS
	IFS=";"
	ZONES=""
	for ZONEURI in $(gcloud compute regions describe $REGION --format="value(zones)"); do
		ZONES=${ZONES},$(basename $ZONEURI)
	done
	IFS=$OLDIFS
	ZONES=${ZONES:1}
}

# scale to 1 and wait
function gcloudrig_start {

	gcloud compute instance-groups managed resize $INSTANCEGROUP \
		--size 1 \
		--region $REGION \
		--quiet

	gcloud compute instance-groups managed wait-until-stable $INSTANCEGROUP \
		--region $REGION \
		--quiet

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

	# create boot disk snapshot (with VSS, just in case it's still running)
	gcloud compute disks snapshot $BOOTDISK \
		--snapshot-names $BOOTSNAP \
		--zone $ZONE \
		--guest-flush \
		--quiet || echo "assuming $BOOTSNAP exists, continuing..."

	# delete existing boot image
	gcloud compute images delete $IMAGE \
		--quiet

	# create boot image from boot snapshot
	gcloud compute images create $IMAGE \
		--source-snapshot $BOOTSNAP \
		--guest-os-features WINDOWS \
		--quiet

	# delete boot snapshot
	gcloud compute snapshots delete $BOOTSNAP \
		--quiet

	# delete boot disk
	gcloud compute disks delete $BOOTDISK \
		--zone $ZONE \
		--quiet || echo "assuming $BOOTDISK is still in use, continuing..."

}

# turn games disk into a snapshot
function gcloudrig_games_disk_to_snapshot {

	# save games snapshot
	GAMESSNAP="$GAMESDISK-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')-snap"
	gcloud compute disks snapshot $GAMESDISK \
		--snapshot-name $GAMESSNAP \
		--zone $ZONE \
		--guest-flush \
		--quiet

	# remove the "latest=true" label from any existing gcloudrig snapshots
	for SNAP in $(gcloud compute snapshots list --format "value(name)" --filter "labels.$DISKLABEL=true"); do
		LATEST=gcloud compute snapshots describe $SNAP --format "value(labels.latest)"
		if [ $LATEST = "true" ]; then
			gcloud compute snapshots remove-labels $SNAP --labels "latest=true"
		fi
	done

	# add labels to the latest snapshot
	gcloud compute snapshots add-labels $GAMESSNAP --labels "latest=true,$DISKLABEL=true"

	# delete games disk
	gcloud compute disks delete $BOOTDISK \
		--zone $ZONE \
		--quiet || echo "assuming $BOOTDISK is still in use, continuing..."

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