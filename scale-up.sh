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

# restore games disk from snapshot
gcloud compute disks create $GAMESDISK --zone $ZONE --source-snapshot $GAMESSNAP --quiet

# attach games disk
gcloud compute instances attach-disk $INSTANCE --disk $DISK --zone $ZONE --quiet

# delete games snapshot (TODO: stop using static snapshot names)
gcloud compute snapshots delete $GAMESSNAP --quiet