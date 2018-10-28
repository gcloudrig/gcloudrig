#!/usr/bin/env bash

# exit on error
set -e

# load globals
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $DIR/globals.sh

# get zones for this region
gcloudrig_set_zones

# copy base image
echo "Creating boot image from latest $IMAGEBASEFAMILY image..."
gcloud compute images create $IMAGE \
	--source-image $(gcloud compute images describe-from-family $IMAGEBASEFAMILY --project $IMAGEBASEPROJECT --format "value(name)") \
	--source-image-project $IMAGEBASEPROJECT \
	--guest-os-features WINDOWS \
	--quiet

# create instance template
echo "Creating instance template $INSTANCETEMPLATE..."
gcloud beta compute instance-templates create $INSTANCETEMPLATE \
	--image $IMAGE \
	--machine-type $INSTANCETYPE \
	--accelerator $INSTANCEACCELERATOR \
	--boot-disk-size $BOOTSIZE \
	--boot-disk-type $BOOTTYPE \
	--maintenance-policy TERMINATE \
	--no-boot-disk-auto-delete \
	--no-restart-on-failure \
	--quiet || echo 'blah'

# create a managed instance group that covers all zones (GPUs tend to be oversubscribed in certain zones)
# and give it the base instance template
echo "Creating managed instance group $INSTANCEGROUP"
gcloud beta compute instance-groups managed create $INSTANCEGROUP \
	--base-instance-name $INSTANCENAME \
	--template $INSTANCETEMPLATE \
	--size 0 \
	--region $REGION \
	--zones $ZONES \
	--initial-delay 300 \
	--quiet || echo 'blah'

# turn it on
echo "Starting gcloudrig"
gcloudrig_start

# add extra volume
echo "Mounting games disk"
gcloudrig_mount_games_disk

# wait for 60 seconds, just in case
echo "Waiting 60 seconds for instance to settle"
sleep 60

# set windows credentials
echo "Retrieving windows credentials"
CREDENTIALS=$(gcloud compute reset-windows-password $INSTANCE \
		--user $USER \
		--zone $ZONE \
		--quiet \
		--format "table[box,title='Windows Credentials'](ip_address,username,password)" \
	)

# shut it down
echo "Stopping gcloudrig"
gcloudrig_stop

# save boot image
echo "Saving new boot image"
gcloudrig_boot_disk_to_image

# save games snapshot
echo "Snapshotting games disk"
gcloudrig_games_disk_to_snapshot

echo "Done!"
echo
echo $CREDENTIALS
echo
echo "Next steps: 
	- Create a disk called '$GAMESDISK'
	- Run \`./scale-up.sh\`
	- Use the above credentials to RDP to the instance
	- Install 'GRID® drivers for virtual workstations'
	- Enable auto login (start > run > 'control userpasswords2')
	- Install parsec, login, and set it to run on boot (right-click in the system tray)
	- Install zerotier and join a network (create a new one if you haven't used zerotier before)
	- Install TightVNC and lock it down to zerotier's IP range for difficult times
	- Reboot and try connect with parsec
	- Run \`./scale-down.sh\`"