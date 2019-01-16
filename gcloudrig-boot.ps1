Function Write-Status {
  Param(
    [parameter(Mandatory=$true,ValueFromPipeLine=$true)] [String] $Text,
    [String] $Sev = "INFO"
  )
  "$Sev $Text" | Write-Output
  gcloud logging write gcloudrig-install --severity="$Sev" "$Text"
}

# restore/create games disk and mounts it if it's not already attached somewhere
function MountGamesDisk {
  $GamesDiskNeedsInit=$false
  $GamesDisk=(Get-GceDisk -DiskName "$GamesDiskName")
  If (-Not $GamesDisk) {
    $LatestSnapshotName=(gcloud compute snapshots list --format "value(name)" --filter "labels.$GCRLABEL=true labels.latest=true" --project (Get-GceMetadata -Path "project/project-id"))
    If ($LatestSnapshotName) {
      $Snapshot=(Get-GceSnapshot -Name "$LatestSnapshotName")
      If ($Snapshot) {
        Write-Status "Restoring games disk from snapshot $LatestSnapshotName..."
        $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Snapshot $Snapshot -Zone "$ZoneName")
      } Else {
        Write-Status "Failed to get snapshot $LatestSnapshotName"
      }
    } Else {
      Write-Status "Creating blank games disk..."
      $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Zone "$ZoneName")
      $GamesDiskNeedsInit=$true
    }
  }

  If ($GamesDisk) {
    If ($GamesDisk.Users -And ($GamesDisk.Users | Split-Path -Leaf) -Eq $Instance.Name) {
      Write-Status "Games Disk is already attached!"
    } Else {
      Write-Status "Attaching games disk..."
      Set-GceInstance $Instance -AddDisk $GamesDisk
      if ($GamesDiskNeedsInit) {
        InitNewDisk
      }
    }
  } Else {
    Write-Status -Sev ERROR "failed to mount games disk"
  }
}

function InitNewDisk {
  try {
    Write-Status "Initialising Games Disk..."
    # stop hardware detection service to avoid a pop-up dialog
    Stop-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
    Get-Disk | Where partitionstyle -eq 'raw' |
      Initialize-Disk -PartitionStyle GPT -PassThru |
      New-Partition -DriveLetter Z -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' |
      Format-Volume -FileSystem NTFS -NewFileSystemLabel "Games" -Confirm:$false
  } catch {
    Write-Status "Failed to initialise Games disk: $_.Exception.Messager"
  } finally {
    Start-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
  }
}

Function Start-Bootstrap {
  Write-Status "Start-Bootstrap"
  Write-Status -Sev DEBUG "download installer module from $SetupScriptUrl"
  & gsutil cp "$SetupScriptUrl" "$Home\Desktop\gcloudrig.psm1" 2>&1 | %{ "$_" }
  if (Test-Path "$Home\Desktop\gcloudrig.psm1") {
    New-Item -ItemType directory -Path "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig" -Force
    Copy-Item "$Home\Desktop\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force
    Import-Module gCloudRig

    # this will force a reboot when finished
    Install-Bootstrap
  } else {
    Write-Status -Sev ERROR "download of gcloudrig.psm1 failed!"
    # TODO: should we reboot here to force a retry or just retry now?
  }
}

Function Run-Software-Setup {
  Write-Status "Run-Software-Setup"
  # Setup states should be
  # 1. new
  # 2. boostrap
  # 3. installing
  # 4. complete
  $SetupStateExists=(Get-GceMetadata -Path "instance/attributes" | Select-String "gcloudrig-setup-state")
  if ($SetupStateExists) {
    $SetupState=(Get-GceMetadata -Path "instance/attributes/gcloudrig-setup-state")
  } else {
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

$SetupScriptUrlAttribute="gcloudrig-setup-script-gcs-url"
if (Get-GceMetadata -Path "project/attributes" | Select-String $SetupScriptUrlAttribute) {
  $SetupScriptUrl=(Get-GceMetadata -Path project/attributes/$SetupScriptUrlAttribute)
}
$ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
$InstanceName=(Get-GceMetadata -Path "instance/name")
$Instance=(Get-GceInstance $InstanceName -Zone "$ZoneName")

# attach games disk
MountGamesDisk

# if set then we want to install software
If ($SetupScriptUrl) {
  Run-Software-Setup
}

Write-Status -Sev DEBUG "gcloudrig-boot.ps1 finished"
