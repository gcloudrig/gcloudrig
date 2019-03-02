# gcloudrig-boot.ps1
#

Function Write-Status {
  Param(
    [parameter(Mandatory=$true,ValueFromPipeLine=$true)] [String] $Text,
    [String] $Sev = "INFO"
  )
  # this goes to the serial console
  "$Sev $Text" | Write-Output
  New-GcLogEntry -Severity "$Sev" -LogName gcloudrig-install -TextPayload "$Text"
}

# restore/create games disk and mounts it if it's not already attached somewhere
function Mount-GamesDisk {
  $GamesDiskNeedsInit=$false

  $ZoneName=(Get-GceMetadata -Path "instance/zone" | Split-Path -Leaf)
  $InstanceName=(Get-GceMetadata -Path "instance/name")
  $Instance=(Get-GceInstance $InstanceName -Zone "$ZoneName")
  
  $GamesDisk=(Get-GceDisk -DiskName "$GamesDiskName")
  If (-Not $GamesDisk) {
    $LatestSnapshotName=(gcloud compute snapshots list --format "value(name)" --filter "labels.$GCRLABEL=true labels.latest=true" --project (Get-GceMetadata -Path "project/project-id"))
    If ($LatestSnapshotName) {
      $Snapshot=(Get-GceSnapshot -Name "$LatestSnapshotName")
      If ($Snapshot) {
        Write-Status "Restoring games disk from snapshot $LatestSnapshotName..."
        $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Snapshot $Snapshot -Zone "$ZoneName")
      } Else {
        Write-Status -Sev ERROR "Failed to get snapshot $LatestSnapshotName"
      }
    } Else {
      Write-Status "Creating blank games disk..."
      $GamesDisk=(New-GceDisk -DiskName "$GamesDiskName" -Zone "$ZoneName")
      $GamesDiskNeedsInit=$true
    }
  }

  If ($GamesDisk) {
    If ($GamesDisk.Users -And ($GamesDisk.Users | Split-Path -Leaf) -Eq $Instance.Name) {
      Write-Status -Sev DEBUG "Games Disk is already attached!"
    } Else {
      Write-Status "Attaching games disk..."
      Set-GceInstance $Instance -AddDisk $GamesDisk
      if ($GamesDiskNeedsInit) {
        Initialize-NewDisk
      }
    }
  } Else {
    Write-Status -Sev ERROR "failed to mount games disk"
  }
}

function Initialize-NewDisk {
  try {
    Write-Status "Initializing Games Disk..."
    # stop hardware detection service to avoid a pop-up dialog
    Stop-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
    Get-Disk | Where partitionstyle -eq 'raw' |
      Initialize-Disk -PartitionStyle GPT -PassThru |
      New-Partition -DriveLetter Z -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' |
      Format-Volume -FileSystem NTFS -NewFileSystemLabel "Games" -Confirm:$false
  } catch {
    Write-Status -Sev ERROR "Failed to initialise Games disk: $_.Exception.Messager"
  } finally {
    Start-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
  }
}

Function Update-GcloudRigModule {
  if (Get-GceMetadata -Path "project/attributes" | Select-String $SetupScriptUrlAttribute) {
    $SetupScriptUrl=(Get-GceMetadata -Path project/attributes/$SetupScriptUrlAttribute)

    & gsutil cp $SetupScriptUrl "$Env:Temp\gcloudrig.psm1"
    if (Test-Path "$Env:Temp\gcloudrig.psm1") {
      New-Item -ItemType directory -Path "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig" -Force
      Copy-Item "$Env:Temp\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force
    }
  }
}


## Main
Write-Status -Sev DEBUG "gcloudrig-boot.ps1 started"

# these need to match globals.sh
$GCRLABEL="gcloudrig"
$GamesDiskName="gcloudrig-games"
$SetupScriptUrlAttribute="gcloudrig-setup-script-gcs-url"

Update-GcloudRigModule 
if (Get-Module -ListAvailable -Name gCloudRig) {
  Import-Module gCloudRig
  Invoke-SoftwareSetupFromBoot
}
Mount-GamesDisk

Write-Status -Sev DEBUG "gcloudrig-boot.ps1 finished"
