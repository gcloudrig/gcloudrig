gcloud logging write gcloudrig-install "windows-setup.ps1 started"

if (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\gcloudriginstaller.lnk") {
  gcloud logging write gcloudrig-install ".startup.lnk detected, exiting GCE startup script"

} else {

  gcloud logging write gcloudrig-install ".download gcloudrig.psm1 from GCS"

  $SetupScriptUrl=Get-GceMetadata -Path "gcloudrig/setup-script-gcs-url"
  $InstanceName=Get-GceMetadata -Path "name"
  $InstanceZone=Get-GceMetadata -Path "zone"

  # download installer module from GCS
  & gsutil cp "$SetupScriptUrl" "$Home\Desktop\gcloudrig.psm1" | Out-File "c:\gcloudrig-setup.txt" -Append
  if (Test-Path "$Home\Desktop\gcloudrig.psm1") {
    New-Item -ItemType directory -Path "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig" -Force
    Copy-Item "$Home\Desktop\gcloudrig.psm1" -Destination "$Env:ProgramFiles\WindowsPowerShell\Modules\gCloudRig\" -Force
    Import-Module gCloudRig

    # create a new account and password
    $Password=gcloud compute reset-windows-password "$InstanceName" --user "gcloudrig" --zone "$InstanceZone" --format "value(password)"

    # TODO: put this somewhere safer
    gcloud logging write gcloudrig-install ".user account created/reset; username:gcloudrig; password:$Password"

    New-gCloudRigInstall -Password "$Password"

  } else {
    gcloud logging write gcloudrig-install --severity ERROR ".download of gcloudrig.psm1 failed!"
  }
}

# announce that we're done
gcloud logging write gcloudrig-install "windows-setup.ps1 finished"

gcloud compute instances add-metadata "$InstanceName" --metadata "gcloudrig-setup-script-finished=true"

