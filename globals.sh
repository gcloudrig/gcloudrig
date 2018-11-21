#!/usr/bin/env bash

# gcloudrig/globals.sh

# region and project?
REGION="australia-southeast1"
PROJECT_ID="gcloudrig"

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
GCRLABEL="gcloudrig"
IMAGE="gcloudrig"
INSTANCEGROUP="gcloudrig-group"
INSTANCENAME="gcloudrig"
INSTANCETEMPLATE="gcloudrig-template"

# always run
function init_globals {
	
	# config
	gcloud config set project "$PROJECT_ID" \
		--quiet

	# set zones for this region
	gcloudrig_set_zones
	
}

# Populate $ZONES with any zones that has the accelerator resources we're after in the $REGION we want
function gcloudrig_set_zones {
	ZONES=""

	local REGIONZONES=()
	mapfile -d ";" -t REGIONZONES < <(gcloud compute regions describe "$REGION" \
		--format="value(zones)")

	local ACCELERATORZONES=()
	mapfile -d ";" -t ACCELERATORZONES < <(gcloud compute accelerator-types list \
		--filter "name=$ACCELERATORTYPE" \
		--format "value(zone)")

	for ZONEURI in "${REGIONZONES[@]}"; do
		local ZONE=""
		ZONE="$(basename -- "$ZONEURI")"
		if [[ ${ACCELERATORZONES[*]} =~ $ZONE ]]; then
			ZONES="${ZONES},${ZONE}"
		fi;
	done

	ZONES="${ZONES:1}"
}

# Get instance name from instance group
function gcloudrig_get_instance_from_group {

	local region="$1"
	local instance_group="$2"
	gcloud compute instance-groups list-instances "$instance_group" \
	--region "$region" \
	--format "value(instance)" \
	--quiet

}

# Get instance zone from instance group
function gcloudrig_get_instance_zone_from_group {

	local region="$1"
	local instance_group="$2"
	gcloud compute instance-groups list-instances "$instance_group" \
	--region "$region" \
	--format "value(instance.scope().segment(0))" \
	--quiet

}

# Get bootdisk from instance
function gcloudrig_get_bootdisk_from_instance {

	local zone="$1"
	local instance="$2"
	gcloud compute instances describe "$instance" \
		--zone "$zone" \
		--format "value(disks[0].source.basename())" \
		--quiet

}

function wait_utill_instance_group_is_stable {

	gcloud compute instance-groups managed wait-until-stable "$INSTANCEGROUP" \
		--region "$REGION" \
		--quiet

}

# scale to 1 and wait, with retries every 5 minutes
function gcloudrig_start {

	# scale to 1
	gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
		--size "1" \
		--region "$REGION" \
		--format "value(currentActions)" \
		--quiet

	# if it doesn't start in 5 minutes
	while ! timeout 300 wait_utill_instance_group_is_stable; do

		# scale it back down
		gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
			--size "0" \
			--region "$REGION" \
			--format "value(currentActions)" \
			--quiet

		# wait
		wait_utill_instance_group_is_stable

		# and back up again (chance of being spawned in a different zone)
		gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
			--size "1" \
			--region "$REGION" \
			--format "value(currentActions)" \
			--quiet
	done

	# we have an instance!
	INSTANCE="$(gcloudrig_get_instance_from_group "$REGION" "$INSTANCEGROUP")"
	ZONE="$(gcloudrig_get_instance_zone_from_group "$REGION" "$INSTANCEGROUP")"
	BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"

}

# scale to 0 and wait
function gcloudrig_stop {

	INSTANCE="$(gcloudrig_get_instance_from_group "$REGION" "$INSTANCEGROUP")"
	ZONE="$(gcloudrig_get_instance_zone_from_group "$REGION" "$INSTANCEGROUP")"
	BOOTDISK="$(gcloudrig_get_bootdisk_from_instance "$ZONE" "$INSTANCE")"

	gcloud compute instance-groups managed resize "$INSTANCEGROUP" \
		--size "0" \
		--region "$REGION" \
		--quiet

	wait_utill_instance_group_is_stable

}

# turn boot disk into an image
function gcloudrig_boot_disk_to_image {

	echo "Creating boot image, this may take some time..."

	# delete existing boot image
	gcloud compute images delete "$IMAGE" --quiet \
		|| echo "assuming $IMAGE doesn't exist, continuing..."

	# create boot image from boot disk
	gcloud compute images create "$IMAGE" \
		--source-disk "$BOOTDISK" \
		--source-disk-zone "$ZONE" \
		--guest-os-features WINDOWS \
		--labels "$GCRLABEL=true" \
		--quiet

	# delete boot disk
	gcloud compute disks delete "$BOOTDISK" \
		--zone "$ZONE" \
		--quiet

}

# turn games disk into a snapshot
function gcloudrig_games_disk_to_snapshot {

	# save games snapshot, but don't label it yet
	GAMESSNAP="$GAMESDISK-$(mktemp --dry-run XXXXXX | tr '[:upper:]' '[:lower:]')-snap"
	gcloud compute disks snapshot "$GAMESDISK" \
		--snapshot-names "$GAMESSNAP" \
		--zone "$ZONE" \
		--guest-flush \
		--quiet

	# find existing snapshots
	local SNAPSHOTS=()
	mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
			--format "value(name)" \
		--filter "labels.$GCRLABEL=true")

	# remove the "latest=true" label from all existing gcloudrig snapshots
	for SNAP in "${SNAPSHOTS[@]}"; do
		LATEST="$(gcloud compute snapshots describe "$SNAP" \
			--format "value(labels.latest)")"
		if [ "$LATEST" = "true" ]; then
			gcloud compute snapshots remove-labels "$SNAP" \
				--labels "latest"
		fi
	done

	# add labels to the latest snapshot
	gcloud compute snapshots add-labels "$GAMESSNAP" \
		--labels "latest=true,$GCRLABEL=true"

	# delete games disk
	gcloud compute disks delete "$GAMESDISK" \
		--zone "$ZONE" \
		--quiet \
		|| echo "assuming $GAMESDISK is still in use, continuing..."

}

# mounts games disk, restoring from latest snapshot or creating a new one if nessessary
# no size/disk type specifified; gcloud will default to 500GB pd-standard when creating
function gcloudrig_mount_games_disk {

	# get latest games snapshot
	GAMESSNAP="$(gcloud compute snapshots list \
		--format "value(name)" \
		--filter "labels.gcloudrig=true labels.latest=true")"

	# restore games snapshot
	# or create a new games disk
	# or just keep going and assume a games disk already exists
	gcloud compute disks create "$GAMESDISK" \
		--zone "$ZONE" \
		--source-snapshot "$GAMESSNAP" \
		--quiet \
		--labels "$GCRLABEL=true" \
		|| gcloud compute disks create "$GAMESDISK" \
			--zone "$ZONE" \
			--quiet \
			--labels "$GCRLABEL=true" \
			|| echo "assuming $GAMESDISK exists, continuing..."

	# attach games disk
	gcloud compute instances attach-disk "$INSTANCE" \
	--disk "$GAMESDISK" \
	--zone "$ZONE" \
	--quiet

}

# Fire! 
init_globals;
