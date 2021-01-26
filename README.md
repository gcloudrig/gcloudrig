# gcloudrig <img alt="Logo" src="https://cdn.pixabay.com/photo/2016/10/30/23/05/controller-1784573_1280.png" width="40" height="40" />

A collection of bash scripts to help create and maintain a cloud gaming rig in Google Cloud Platfom, on the cheap.

### Quickstart
[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/compute/instances?cloudshell_git_repo=https://github.com/putty182/gcloudrig&cloudshell_print=QUICKSTART.md)

### Prerequisites
- A Google Cloud project with an active billing account and [GPU Quota](https://cloud.google.com/compute/quotas#requesting_additional_quota).
- A working bash shell with the [gcloud](https://cloud.google.com/sdk/install) command.  
   - Google's [Cloud Shell](https://cloud.google.com/shell) will do just fine
   
It's also recommended to install the following on your local device (PC, Mac, Android, etc) that you'll be streaming to :
-  [Parsec](https://parsecgaming.com/) for low-latency streaming
-  [ZeroTier](https://zerotier.com/) for secure networking
-  a VNC client (e.g. [TightVNC](https://www.tightvnc.com/)) for backup access

### Specs & Costs
You'll be charged for the following resources while your rig is running:
-  CPU/RAM: 8 vCPUs, 30 GB Memory ([n1-standard-8](https://cloud.google.com/compute/all-pricing#n1_standard_machine_types))
-  GPU: NVIDIA® T4 Virtual Workstation ([nvidia-tesla-t4-vws](https://cloud.google.com/compute/gpus-pricing#gpus))
-  OS: Windows Server 2019 ([windows-2019](https://cloud.google.com/compute/all-pricing#windows_server_pricing))
-  Boot Disk: 50GB SSD persistent disk ([pd-ssd](https://cloud.google.com/compute/all-pricing#persistentdisk))
-  Games Disk: 500GB standard persistent disk ([pd-standard](https://cloud.google.com/compute/all-pricing#persistentdisk))
-  Network Costs ([egress](https://cloud.google.com/vpc/network-pricing#internet_egress))

You'll also be charged for the following while your rig is running and at rest:
- Boot Disk storage (billed at [Custom Image](https://cloud.google.com/compute/all-pricing#imagestorage) rates)
- Games Disk storage (billed at [Cloud Storage](https://cloud.google.com/storage/pricing#storage-pricing) rates)

*Cloud responsibly. These scripts are provided as-is, with minimal support. While they're designed to minimise costs at-rest, things may not always go to plan.  It's recommended to use a dedicated GCP project and/or billing account with billing alerts to avoid any nasty suprises.*


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

   You can use https://cloudharmony.com/speedtest-latency-for-google:compute to test for latency and find your closest region.
   
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
- Install [GRID® drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/install-grid-drivers#grid-driver-windows)
- Install [Virtual Audio Cable](https://www.vb-audio.com/Cable/) to use as a virtual sound card
- Install [ZeroTier](https://zerotier.com/), zcreate/join a network and set it to run on boot by right-clicking it's icon in the System Tray
- Reboot to finish GPU driver installation.
- Login with TightVNC, set display to an appropriate screen resolution and disable any other non-GPU displays
- Attempt to change the volume; Windows should prompt that the Windows Sound service isn't running.  Start it.  Alternatviely, run `services.msc` and change it's startup options there.
- Install [Parsec](https://parsecgaming.com/) or your choice of streaming software
- Setup [Autologon](https://docs.microsoft.com/en-au/sysinternals/downloads/autologon) to bypass the lock screen on boot.
   - If automatic login fails, or you access your instance with RDP then the lock screen will prevent most streaming software from working.  You can use TightVNC to access the lock screen.
   - Alternatively, use RDP and an [unlock script](https://steamcommunity.com/groups/homestream/discussions/0/617335934139051123/) to drop the RDP session directly to the local console, securely bypassing the lock screen.
- Install game clients (e.g. Steam, Battlenet) and enjoy!

## Starting your rig
Run `./scale-up.sh` to start your instance.

After your rig has started, it will create a new games disk or restore an existing one from a snapshot and attach it to itself.

## Stopping your rig
Run `./scale-down.sh` to shutdown your instance.

Once stopped, it will take a few minutes to pack away the boot disk and games disk.  Read [What happens when I stop my rig?](#what-happens-when-i-stop-my-rig?) below for more info.

## Troubleshooting
If you're having difficulty connecting with a game streaming client, use RDP or TightVNC to access your machine.
- RDP can't be used to control your rig's local display (which can upset Parsec, especially if it's stuck on the lock screen).  There is a desktop hack to "drop" the remote session to the local display, but it's not always reliable.
- TightVNC can control the local display and interact with the lock screen, but is less reliable and less secure.  It's locked down to your Zerotier network during initial setup, just in case.

If you forget your password, use `./reset-windows-password.sh` to get a new one.  Note that when you do this, you'll also need to update the password for automatic login (use Start > Run > `control userpasswords2`)

If you need to setup a custom resolution (e.g. 1800x1200), you might have issues with the native NVidia drivers. [Custom Resolution Utility (CRU)](https://www.monitortests.com/forum/Thread-Custom-Resolution-Utility-CRU) works well, and while the automatic options in Parsec should also work you can [force it to behave too](https://support.parsecgaming.com/hc/en-us/articles/360003146311-Force-A-Server-Resolution-Change).

If you need a nuclear option, delete everything and start over with these commands:
````
$ ./destroy.sh
$ ./setup.sh
````

## Maintainence and FAQ

### What happens when I stop my rig?
During the scale-down script, your boot disk (C:\) is stored away as a [custom image](https://cloud.google.com/compute/disks-image-pricing#imagestorage), and your games disk (G:\) is stored away as a [persistent disk snapshot](https://cloud.google.com/compute/docs/disks/snapshots).  These are the only two at-rest costs that should be associated with your rig.

### Can I resize my disks?
If you need more space or faster disk performance, you can always [increase the size of your disks](https://cloud.google.com/compute/docs/disks/add-persistent-disk#resize_pd) while your rig is running.

It's recommended to keep usage on your boot disk (C:\) as small as possible, since at-rest it's stored as a custom image which has higher pricing than the snapshots used to store the games disk (G:\).

To take advantage of the (performance boost)[https://cloud.google.com/compute/docs/disks/performance] from having a larger disk but limit your actual disk usage for at-rest costs, after resize simply shrink the volume back down in Windows Disk Manager.

### The maximum resolution is 1366x768 or 1280×1024 or my framerate drops to 15fps after 20 minutes
These are all symptoms of NVIDIA GRID / Quadro Licence failures;  the best suggestion is to reinstall the [GRID® drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/install-grid-drivers#grid-driver-windows) and restart your rig.

### Where do I find the licenced NVIDIA GRID Drivers?
The easiest way to browse and download the drivers is using the Storage Browser in Google Cloud Console: https://console.cloud.google.com/storage/browser/nvidia-drivers-us-public/GRID

## Travelling?
gcloudrig keeps your rig as a boot image and disk snapshot in the same GCE region. To move your rig to a different part of the world, just run `./change-region.sh` to change your default region, then run `./scale-up.sh`.  Restoring snapshots in a different region may incurr [network costs](https://cloud.google.com/compute/docs/disks/create-snapshots#network_costs), so be careful!

## Contributing
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/putty182/gcloudrig/tree/develop)

Pull requests against the [develop](https://github.com/putty182/gcloudrig/tree/develop) branch are welcome!
