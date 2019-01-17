
# Current setup.sh flow in master

* setup.sh
  * gcloudrig_create_instance_group
    * creates instance group with -setup template
      which sets windows-startup-script-ps1 to gcloudrig-setup.ps1

* scale-up.sh
  * gcloudrig_start
    * if the instance fails to come up in time runs update_instance_group
      which would change the startup script and not run the initial install

  * gcloudrig_update_instance_group
    * creates new instance template with windows-startup-script-ps1 to gcloudrig-boot.ps1

# Previous setup.sh flow

```
copy gcloudrig.psm1 to GCS
store URI for gcloudrig.psm1 in project metadata 

gcloudrig_start            
gcloudrig_mount_games_disk # now in gcloudrig-boot.ps1

[1] VM boots and runs gcloudrig-setup.ps1 at boot
  gcloudrig-setup.ps1
    checks for .lnk startup file
      not found # first install
        copies gcloudrig.psm1 from GCS
        starts New-gCloudRigInstall

  gcloudrig.psm1:New-gCloudRigInstall
    setups up autologin # for further reboots
    creates initGamesDiskScript.ps1
    schedules a task to run initGamesDiskScript
    creates installer.ps1 script
    creates gcloudriginstaller.lnk file in Startup dir to run installer.ps1
    reboots

[2] VM boots and runs gcloudrig-setup.ps1 at boot
  gcloudrig-setup.ps1
    checks for .lnk startup file
      found, exits

  windows starts
    autologin happens and gcloudriginstaller.lnk runs installer.ps1

  installer.ps1
    checks user is gcloudrig -> if not exit
    checks for c:\gcloudrig\downloads
      not found # assumes this is initial run
        run Install-gCloudRig as job gCloudRigInstaller

  gcloudrig.psm1:Install-gCloudRig
    creates dir c:\gcloudrig\downloads # flagging that install has started

    starts install and reboots

[3] VM boots and runs gcloudrig-setup.ps1 at boot
  gcloudrig-setup.ps1
    checks for .lnk startup file
      found, exits

  windows starts
    autologin happens and gcloudriginstaller.lnk runs installer.ps1

  installer.ps1
    checks user is gcloudrig -> if not exit
    checks for c:\gcloudrig\downloads
      found
        resume job gCloudRigInstaller

  gcloudrig.psm1:Install-gCloudRig
    installs more stuff and reboots

[several more reboots, flow follows 3]

[6] VM boots and runs gcloudrig-setup.ps1 at boot
  gcloudrig-setup.ps1
    checks for .lnk startup file
      found, exits

  windows starts
    autologin happens and gcloudriginstaller.lnk runs installer.ps1

  installer.ps1
    checks user is gcloudrig -> if not exit
    checks for c:\gcloudrig\downloads
      found
        resume job gCloudRigInstaller

  gcloudrig.psm1:Install-gCloudRig
    removes gcloudriginstaller.lnk 
    prints "all done"

  # startup script metadata needs to be removed before next boot or
  # gcloudrig-setup.ps1 will start an install again since startup .lnk is gone
```

# New flow

```
setup.sh
  asks if user wants s/w installed (make it a cmdline option too)
  if yes
    upload gcloudrig.psm1 to GCS
    put GCS URI in project metadata

gcloudrig_create_instance_group
  set windows startup script to gcloudrig-boot.ps1

gcloudrig-boot.ps1
  attach games disk
  do we want software installed? (if GCS URI is set in project metadata)
    what state are we in? (GCE instance metadata)
      new?
        download installer
        set state to bootstrap
        run installer-bootstrap
        reboot
      bootstrap?
        is startup.lnk present?
          no, ERROR
          yes, continue boot (startup.lnk will takeover)
      installing?
        continue boot
      complete?
        continue boot

gcloudrig.psm1
  installer-bootstrap
    create dirs
    create installer.ps1 and startup.lnk to run it
    create disk init script and schedule job
    reboot

startup.lnk/installer.ps1
  is user gcloudrig
    no, exit
  
  what state are we in?
    bootstrap?
      start Install-gCloudRig job "gCloudRigInstaller"
      
    installing?
      resume gCloudRigInstaller

    complete?
      exit

    new?
      exit

gcloudrig.psm1
  Install-gCloudRig
    set state to installing
    install stuff
    at end of script, set state to Complete

```

