#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

# shut it down
gcloudrig_stop

# create boot disk and games disk snapshots
gcloud compute disks snapshot $BOOTDISK $GAMESDISK \
	--snapshot-names $BOOTSNAP,$GAMESSNAP \
	--zone $ZONE \
	--quiet \
	--guest-flush

# delete old boot image
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

# delete boot disk and games disk
gcloud compute disks delete $BOOTDISK $GAMESDISK \
	--zone $ZONE \
	--quiet
