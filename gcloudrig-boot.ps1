Function Write-Status {
  Param(
    [parameter(Mandatory=$true),ValueFromPipeLine=$true] [String] $Text,
    [String] $Sev = "INFO",
  )
  "$(Date) $Sev $Text" | Out-File "c:\gcloudrig-boot.txt" -Append
  gcloud logging write gcloudrig-install --severity="$Sev" "$Text"
}

# restore/create games disk and mounts it if it's not already attached somewhere
function MountGamesDisk {
  $GamesDisk=(Get-GceDisk -DiskName "$GamesDiskName")
  If (-Not $GamesDisk) {
    $LatestSnapshotName=(gcloud compute snapshots list --format "value(name)" --filter "labels.$GCRLABEL=true labels.latest=true" --project (Get-GceMetadata -Path "project/project-id"))
    $Snapshot=(Get-GceSnapshot -Name "$LatestSnapshotName")
    If ($Snapshot) {
      Write-Status "Restoring games disk from snapshot $Snapshot..."
      $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Snapshot $Snapshot -Zone "$ZoneName")
    } Else {
      Write-Status "Creating blank games disk..."
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

Function Start-Bootstrap {
  # download installer module from GCS
  & gsutil cp "$SetupScriptUrl" "$Home\Desktop\gcloudrig.psm1" | Write-Status "c:\gcloudrig-setup.txt"
  if (Test-Path "$Home\Desktop\gcloudrig.psm1") {
    New-Item -ItemType directory -Path "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig" -Force
    Copy-Item "$Home\Desktop\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force
    Import-Module gCloudRig

    # create a new account and password
    $Password=gcloud compute reset-windows-password "$InstanceName" --user "gcloudrig" --zone "$ZoneName" --format "value(password)"

    # TODO: put this somewhere safer
    Write-Status "user account created/reset; username:gcloudrig; password:$Password"

    # this will force a reboot when finished
    Bootstrap-gCloudRigInstall -Password "$Password"
  } else {
    Write-Status -Sev ERROR "download of gcloudrig.psm1 failed!"
    # TODO: should we reboot here to force a retry or just retry now?
  }
}

Function Run-Software-Setup {
  # Setup states should be
  # 1. new
  # 2. boostrap
  # 3. installing
  # 4. complete
  $SetupState=Get-GceMetadata -Path "instance/attributes/gcloudrig-setup-state"
  if(-Not $SetupState) {
    # not set, assume this is first boot
    # TODO: this is fragile, need a better way to set this on the instance for first boot
    $SetupState = "new"
  }
  switch($SetupState) {
    "new" { Start-Bootstrap; break }
    "bootstrap" {
      $ShortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk"
      If (Test-Path "$ShortcutPath") {
        Write-Status -Sev DEBUG "gcloudrig-boot.ps1: state bootstrap, startup .lnk exists"
      } Else {
        Write-Status -Sev DEBUG "gcloudrig-boot.ps1: state bootstrap, startup .lnk missing"
      }  
      break
      }
    "installing" {
      Write-Status -Sev DEBUG "gcloudrig-boot.ps1: state installing"
      break
      }
    "complete" {
      Write-Status -Sev DEBUG "gcloudrig-boot.ps1: state complete"
      break
      }
    default {
      Write-Status -Sev DEBUG ("gcloudrig-boot.ps1: unknown state {0}" -f $_)
      break
      }
  }
}


# main
Write-Status -Sev DEBUG "gcloudrig-boot.ps1 started"

# these need to match globals.sh
$GCRLABEL="gcloudrig"
$GamesDiskName="gcloudrig-games"

$SetupScriptUrl=Get-GceMetadata -Path "gcloudrig/setup-script-gcs-url"
$ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
$InstanceName=(Get-GceMetadata -Path "instance/name")
$Instance=(Get-GceInstance $InstanceName -Zone "$ZoneName")

# attach games disk
MountGamesDisk

# if set then we want to install software
If ($SetupScripUrl) {
  Run-GCloudRig-Setup
}

Write-Status -Sev DEBUG "gcloudrig-boot.ps1 finished"
