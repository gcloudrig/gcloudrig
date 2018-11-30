$GAMESDISK="gcloudrig-games"
$GCRLABEL="gcloudrig"

$PROJECT=(Get-GceMetadata -Path "project/project-id")
$INSTANCE=(Get-GceMetadata -Path "instance/name")
$ZONE=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)


$snapshot=(gcloud compute snapshots list --format "value(name)" --filter "labels.gcloudrig=true labels.latest=true" --project=$PROJECT)
$existingdisk=(gcloud compute disks list --filter "name=$GAMESDISK zone:($ZONE)" --format "value(name)")

# create a blank games disk
If (-Not $snapshot -And -Not $existingdisk) {
    echo "Creating a blank games disk..."
    gcloud compute disks create "$GAMESDISK" --zone "$ZONE" --quiet --labels "$GCRLABEL=true"
} 

# restore snapshot
ElseIf (-Not $existingdisk) {
    echo "Restoring games disk from snapshot $snapshot..."
    gcloud compute disks create "$GAMESDISK" --zone "$ZONE" --quiet --labels "$GCRLABEL=true" --source-snapshot "$snapshot"
}

# disk now exists, so attach it
echo "Mounting games disk..."
gcloud compute instances attach-disk "$INSTANCE" --disk "$GAMESDISK" --zone "$ZONE" --quiet

# restart
echo "Rebooting..."
Restart-Computer -Force