#!/usr/bin/env bash

# exit on error
set -e

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"

# init setup
init_setup

# if image doesn't already exist
if ! gcloud compute images describe "$IMAGE" --format "value(name)" &>/dev/null; then

  # create one from the base image
  gcloud compute images create "$IMAGE" \
    --source-image-family "$IMAGEBASEFAMILY" \
    --source-image-project "$IMAGEBASEPROJECT" \
    --guest-os-features "WINDOWS" \
    --family "$IMAGEFAMILY" \
    --labels "$GCRLABEL=true"

fi

echo "Deleting existing instance group and template"
gcloud compute instance-groups managed delete "$INSTANCEGROUP" --region "$REGION" --quiet &>/dev/null || echo
gcloud compute instance-templates delete "$INSTANCETEMPLATE" --quiet &>/dev/null || echo

# create/recreate actual instance template
echo "Creating instance template $INSTANCETEMPLATE..."
gcloud compute instance-templates create "$INSTANCETEMPLATE" \
  --image "$IMAGE" \
  --machine-type "$INSTANCETYPE" \
  --accelerator "type=$ACCELERATORTYPE,count=$ACCELERATORCOUNT" \
  --boot-disk-type "$BOOTTYPE" \
  --maintenance-policy "TERMINATE" \
  --no-boot-disk-auto-delete \
  --no-restart-on-failure \
  --labels "$GCRLABEL=true" \
  --quiet &>/dev/null

# create a managed instance group that covers all zones (GPUs tend to be oversubscribed in certain zones)
# and give it the base instance template
echo "Creating managed instance group '$INSTANCEGROUP'..."
gcloud compute instance-groups managed create "$INSTANCEGROUP" \
  --region "$REGION" \
  --base-instance-name "$INSTANCENAME" \
  --template "$INSTANCETEMPLATE" \
  --size "0" \
  --zones "$ZONES" \
  --format "value(name)" \
  --quiet &>/dev/null

echo "Done!  Run './scale-up.sh' to start your instance."
