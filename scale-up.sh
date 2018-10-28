#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

# start it up
gcloudrig_start

# don't exit on error
set +e

# restore games disk from snapshot, or create a blank one if the snapshot doesn't exist
gcloud compute disks create $GAMESDISK \
	--zone $ZONE \
	--source-snapshot $GAMESSNAP \
	--quiet || \
	gcloud compute disks create $GAMESDISK \
		--zone $ZONE \
		--quiet || echo "continuing"

# attach games disk
gcloud compute instances attach-disk $INSTANCE \
	--disk $GAMESDISK \
	--zone $ZONE \
	--quiet

# delete games snapshot (TODO: stop using static snapshot names)
gcloud compute snapshots delete $GAMESSNAP \
	--quiet