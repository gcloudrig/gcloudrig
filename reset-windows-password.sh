#!/usr/bin/env bash

# gcloudrig/setup.sh

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "$DIR/globals.sh"

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

# set/reset windows credentials
gcloud compute reset-windows-password "$INSTANCE" \
	--user "$USER" \
	--zone "$ZONE" \
	--format "table[box,title='Windows Credentials'](ip_address,username,password)"
