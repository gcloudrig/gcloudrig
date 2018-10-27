#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $DIR/globals.sh

# delete managed instance group
gcloud compute instance-groups managed delete $INSTANCEGROUP --region $REGION --quiet || sleep 1

# delete instance templates
gcloud compute instance-templates delete $INSTANCETEMPLATE-base --quiet || sleep 1
gcloud compute instance-templates delete $INSTANCETEMPLATE --quiet || sleep 1