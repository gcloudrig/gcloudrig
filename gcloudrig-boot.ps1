$GCRLABEL, $GamesDiskName, $ZoneName, $InstanceName, $Instance, $GamesDisk, $LatestSnapshotName, $Snapshot

# restore/create games disk and mounts it if it's not already attached somewhere
function MountGamesDisk {
    If (-Not $GamesDisk) {
        If ($Snapshot) {
            Write-Output "Restoring games disk..."
            $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Snapshot $Snapshot -Zone "$ZoneName")
        } Else {
            Write-Output "Creating blank games disk..."
            $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Zone "$ZoneName")
        }
    }

    If ($GamesDisk.Users -And ($GamesDisk.Users | Split-Path -Leaf) -Eq $Instance.Name) {
        Write-Output "Games Disk is already attached!"
    } Else {
        Write-Output "Mounting games disk..."
        Set-GceInstance $Instance -AddDisk $GamesDisk
    }
}

function BootCompleted {
    Set-GceInstance $Instance -AddMetadata @{ "gcloudrig-boot" = "true"; }
    Restart-Computer -Force -Wait
}

# business time
if (-Not (Get-GceMetadata -Path "instance/attributes/gcloudrig-boot") -Eq "true") {
    $GCRLABEL="gcloudrig"
    $GamesDiskName="gcloudrig-games"
    $ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
    $InstanceName=(Get-GceMetadata -Path "instance/name")
    $Instance=(Get-GceInstance $InstanceName -Zone "$ZoneName")
    $GamesDisk=(Get-GceDisk -DiskName "$GamesDiskName")
    $LatestSnapshotName=(gcloud compute snapshots list --format "value(name)" --filter "labels.$GCRLABEL=true labels.latest=true" --project (Get-GceMetadata -Path "project/project-id"))
    $Snapshot=(Get-GceSnapshot -Name "$LatestSnapshotName")

    MountGamesDisk
    BootCompleted
}
