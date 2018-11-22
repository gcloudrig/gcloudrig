#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_globals;

# shut it down
gcloudrig_stop || echo -n

# delete managed instance group
gcloud compute instance-groups managed delete "$INSTANCEGROUP" --region "$REGION" || echo -n

# delete instance templates
gcloud compute instance-templates delete "$INSTANCETEMPLATE" || echo -n

# delete image
gcloud compute images delete "$IMAGE" || echo -n

# delete snapshots
SNAPSHOTS=()
mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
  --format "value(name)" \
--filter "labels.$GCRLABEL=true")

# remove the "latest=true" label from all existing gcloudrig snapshots
for SNAP in "${SNAPSHOTS[@]}"; do
  gcloud compute snapshots delete "$SNAP"
done