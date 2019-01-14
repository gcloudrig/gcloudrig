#!/usr/bin/env bash

# exit on error
set -e
[ -n "$GCLOUDRIG_DEBUG" ] && set -x

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_gcloudrig;

# shut it down
gcloudrig_stop || echo -n

# delete managed instance group
gcloudrig_delete_instance_group 

# delete images
images=()
mapfile -t images < <(gcloud compute images list \
  --format "value(name)" \
  --filter "labels.$GCRLABEL=true")
for image in "${images[@]}"; do
  gcloud compute images delete "$image" || echo -n
done

# delete snapshots
SNAPSHOTS=()
mapfile -t SNAPSHOTS < <(gcloud compute snapshots list \
  --format "value(name)" \
  --filter "labels.$GCRLABEL=true")
for SNAP in "${SNAPSHOTS[@]}"; do
  gcloud compute snapshots delete "$SNAP" || echo -n
done
