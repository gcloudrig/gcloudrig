[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/putty182/gcloudrig)

[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/putty182/gcloudrig)

# gcloudrig <img alt="Logo" src="https://cdn.pixabay.com/photo/2016/10/30/23/05/controller-1784573_1280.png" width="40" height="40" />

A collection of bash scripts to help create and maintain a cloud gaming rig in Google Cloud Platfom, on the cheap.

### Quickstart

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/compute/instances?cloudshell_git_repo=https://github.com/putty182/gcloudrig&cloudshell_print=QUICKSTART.md)

Note: you will require a Google Cloud project with an active billing account to launch your rig.


### Prerequisites
-  bash
-  python 2.7.x
-  [gcloud sdk](https://cloud.google.com/sdk/install)
-  [ZeroTier](https://zerotier.com/) (recommended)
-  [Parsec](https://parsecgaming.com/) (recommended)

- [ZeroTier](https://zerotier.com/)
- [TightVNC Client](https://www.tightvnc.com/)
- [Parsec](https://parsecgaming.com/)

### Specs
-  8 vCPU (n1-standard-8)
-  NVIDIA Tesla P4 (nvidia-tesla-p4-vws)
-  50GB SSD (pd-ssd)
-  500GB Storage (pd-standard)
-  Windows Server 2016 (windows-2016)

*Cloud responsibly. These scripts are provided as-is, with zero support. At the very least, create a new GCP project.*

## Setup
-  Create a new GCP project
-  [Launch Cloud Shell](https://cloud.google.com/shell/docs/starting-cloud-shell)
   - Linux/WSL users: Launch a bash shell locally and run `gcloud init`
-  Clone this repository:
   ````
   $ git clone "https://github.com/putty182/gcloudrig"
   ````
-  Run `setup.sh` and follow the prompts
   ````
   $ cd "gcloudrig"
   $ ./setup.sh
   
   Created [gcloudrig].
   Activated [gcloudrig].

   You can use http://gcping.com to find the closest region
   
   Select a region to use:
   1) asia-southeast1          5) us-central1
   2) australia-southeast1     6) us-east4
   3) europe-west4             7) us-west2
   4) northamerica-northeast1
   #? 2
   
   Would you like to automatically install some things? [y/n] y

   1) InstallBattlenet=false  4) ZeroTierNetwork=
   2) InstallSteam=false      5) Done
   3) VideoMode=1920x1080
   #? 1

   1) InstallBattlenet=true  3) VideoMode=1920x1080    5) Done
   2) InstallSteam=false     4) ZeroTierNetwork=
   #? 2

   1) InstallBattlenet=true  3) VideoMode=1920x1080    5) Done
   2) InstallSteam=true      4) ZeroTierNetwork=
   #? 4

   We strongly recommend you create a new ZeroTier network for Gcloudrig
   https://my.zerotier.com/network

   Gcloudrig ZeroTier network id [or quit]: abcdef1234567890

   1) InstallBattlenet=true             3) VideoMode=1920x1080               5) Done
   2) InstallSteam=true                 4) ZeroTierNetwork=abcdef1234567890
   #? 5
   
   Enabling Gcloudrig software installer...
   Creating instance template 'gcloudrig-setup-template'...
   Creating managed instance group 'gcloudrig-group'...
   
   Done!  Run './scale-up.sh' to start your instance.

   ````
- Run `./scale-up.sh` to start your instance.
   - Your instance will launch and automatically start installing software, which will take around 10-20 mins to finish.  Open the [Log Viewer](https://console.cloud.google.com/logs/viewer?resource=global&minLogLevel=200) to track it's progress.

### Connect and finish setup (not automatic, yet)
-  Open your [ZeroTier network](https://my.zerotier.com/network); scroll down to the Members section and mark the *Auth?* checkbox next to your gcloudrig.  You can verify the correct host by matching the Physical IP against your [running compute instances](https://console.cloud.google.com/compute/instances).
-  Use [Remote Desktop](https://www.microsoft.com/p/microsoft-remote-desktop/9wzdncrfj3ps) to connect to your rig with the ZeroTier IP.  Your username and password can be found in the [logs](https://console.cloud.google.com/logs/viewer?resource=global&minLogLevel=200).
-  Finish the Parsec installation, login and enable hosting.
   - [Configure Parsec to only listen on the ZeroTier IP](https://support.parsecgaming.com/hc/en-us/articles/115002766652-Setting-Up-A-VPN-To-Play-Games-On-A-Virtual-Local-Network), or use the [VPC Firewall](https://cloud.google.com/vpc/docs/using-firewalls) to open up the ports required for Parsec (see [Parsec Port Forwarding](https://support.parsecgaming.com/hc/en-us/articles/115002770371-Setting-Up-Port-Forwarding-On-Your-Router) for guidance).
-  Double-click the *Disconnect RDP* shortcut on the desktop, which will drop your RDP session back to the local screen.  This bypasses the windows lock screen, which Parsec doesn't have permission to see.
-  Use [Parsec](https://ui.parsecgaming.com/) to connect back to your instance.
-  When you reconnect, the Parsec logo should be running in your system tray.  Right-click it, and set it *Run when my computer starts*.
-  If everything seems stable, double-click *Post ZeroTier Setup Security* on the desktop to lock down TightVNC and Parsec.
   
### Optional setup
-  Get a free public hostname for your private ZeroTier IP at [Duck DNS](https://www.duckdns.org/).
   -  If you want a hostname for your dynamic public IP as well, you'll need to install a DDNS client or a startup script.
- Restrict public access to RDP ports by modifying the `default-allow-rdp` rule in [VPC Firewall](https://cloud.google.com/vpc/docs/using-firewalls).


## Manual software installation
If you answered No to automatic installation during `./setup.sh`, run `./scale-up.sh` and a clean Windows Server instance will be created.

Run `./reset-windows-password.sh` to get the IP, Username and Password, then connect to your instance with [Remote Desktop](https://www.microsoft.com/p/microsoft-remote-desktop/9wzdncrfj3ps).  See [Creating Passwords for Windows Instances](https://cloud.google.com/compute/docs/instances/windows/creating-passwords-for-windows-instances) and [Connecting to Windows Instances](https://cloud.google.com/compute/docs/instances/connecting-to-instance#windows) for more info.

We recomend the following software, but feel free to find your own:
- Install [GRID® drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/add-gpus#installing_gridwzxhzdk37_drivers_for_virtual_workstations)
- Install [Virtual Audio Cable](https://www.vb-audio.com/Cable/) to use as a virtual sound card
- Install [ZeroTier](https://zerotier.com/), join a network and set it to run on boot by right-clicking it's icon in the System Tray
- Reboot to finish GPU driver installation.
- Login with TightVNC, set display to "Show only on Monitor 2" and give it an appropriate screen resolution.  This will disable the primary 640x480 virtual screen, which can't be resized and gives Parsec headaches when games try to launch on it.
- Attempt to change the volume; Windows should prompt that the Windows Sound service isn't running.  Start it.  Alternatviely, run `services.msc` and change it's startup options there.
- Install [Parsec](https://parsecgaming.com/) or your choice of streaming software
- Setup [Autologon](https://docs.microsoft.com/en-au/sysinternals/downloads/autologon) to bypass the lock screen on boot.
   - If automatic login fails, or you access your instance with RDP then the lock screen will prevent most streaming software from working.  You can use TightVNC to access the lock screen.
   - Alternatively, use RDP and an [unlock script](https://steamcommunity.com/groups/homestream/discussions/0/617335934139051123/) to drop the RDP session directly to the local console, securely bypassing the lock screen.
- Install game clients (e.g. Steam, Battlenet) and enjoy!


## Starting your rig
- Run `./scale-up.sh` to start your instance.

## Stopping your rig
- Run `./scale-down.sh` to shutdown your instance.

  Once stopped, it will take a few minutes to create a copy of both boot and
  games disks.  Read [Disk maintenance](#disk-maintenance) below for more info.

## Troubleshooting
If you're having difficulty connecting with a game streaming client, use RDP or TightVNC to access your machine.
- RDP is more reliable, but can't be used to control the "physical" virtual monitor causing a lock screen to appear (which upsets most streaming clients)
- TightVNC can control the "physical" virtual montior and interact with the lock screen, but is less reliable and less secure.

If you forget your password, use `./reset-windows-password.sh` to get a new one.  If you want to keep [Autologon](https://docs.microsoft.com/en-au/sysinternals/downloads/autologon) working, you'll need to update it with your new password.


If you need to setup a custom resolution (e.g. 1800x1200), you might have issues with the native NVidia drivers. [Custom Resolution Utility (CRU)](https://www.monitortests.com/forum/Thread-Custom-Resolution-Utility-CRU) works well, and while the automatic options in Parsec should also work you can [force it to behave too](https://support.parsecgaming.com/hc/en-us/articles/360003146311-Force-A-Server-Resolution-Change).

If you need a nuclear option, delete everything and start over with these commands:
````
$ ./destroy.sh
$ ./setup.sh
````

## Disk Maintenance

TODO

## Travelling?
gcloudrig keeps your rig as a boot image and disk snapshot in the same GCE region. To move your rig to a different part of the world, just run `./change-region.sh` to change your default region, then run `./scale-up.sh`.  Restoring snapshots in a different region may incurr [network costs](https://cloud.google.com/compute/docs/disks/create-snapshots#network_costs), so be careful!
