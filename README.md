# gcloudrig

A collection of bash scripts that use [Google's Cloud SDK](https://cloud.google.com/sdk/gcloud/) to create and maintain a cloud gaming instance, on the cheap.

Requires `bash`, `gcloud` and `python2` (required by `gcloud`); or just use [Cloud Shell](https://cloud.google.com/shell/).

Default specs:
-  Instance: 8 vCPU; 30GB RAM; 
-  Accelerator: NVidia GRID P4 Virtual Worksatation GPU
-  Boot: 50GB SSD with Windows Server 2016
-  Storage: 500GB Games Disk

*Cloud responsibly. These scripts are provided as-is, with zero support. At the very least, create a new GCP project.*

## Setup
- Edit `./globals.sh` and set `REGION` and `PROJECT` variables.
- Run `./setup.sh`.  This may take 20 minutes, but is only required once.

## Connecting to your instance
- Run `./scale-up.sh` to start your instance.  Depending on what region you're using, this can take anywhere from 60 seconds to whenever a GPU becomes available.
- Run `./reset-windows-password.sh` to get the IP, Username and Password you'll need to RDP to your instance and start installing software.
-- Alternatively, you can reset the password and download an RDP file in [Compute Engine > VM Instances](https://console.cloud.google.com/compute/instances).  See [Creating Passwords for Windows Instances](https://cloud.google.com/compute/docs/instances/windows/creating-passwords-for-windows-instances) and [Connecting to Windows Instances](https://cloud.google.com/compute/docs/instances/connecting-to-instance#windows) for more info.

## Stopping your instance
- Run `./scale-down.sh` to shutdown your instance, and prepare boot image and snapshot so your instance can start up in any zone/region next time.

## (Recommended) Install a bunch of things
- Install [GRID® drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/add-gpus#installing_gridwzxhzdk37_drivers_for_virtual_workstations)
- Install [Virtual Audio Cable](https://www.vb-audio.com/Cable/)
- Setup [Autologon](https://docs.microsoft.com/en-au/sysinternals/downloads/autologon) to avoid a login screen at boot
- Install [ZeroTier](https://zerotier.com/), create/join a network, and set it to run on boot by right-clicking it's icon in the system tray
- Install [TightVNC Server](https://www.tightvnc.com/) and lock it down to zerotier's IP range (e.g. `allow 10.147.17.0-10.147.17.255`; `deny 0.0.0.0-255.255.255`).  Test a VNC connection using your instance's ZeroTier IP now.
- Reboot to finish GPU driver installation.
- Login with TightVNC, set display to "Show only on Monitor 2" and give it an appropriate screen resolution.  This will disable the primary 640x480 virtual screen, which can't be resized and gives Parsec headaches when games try to launch on it.
- Attempt to change the volume; Windows should prompt that the Windows Sound service isn't running.  Start it.  Alternatviely, run `services.msc` and change it's startup options there.
- Install [Parsec](https://parsecgaming.com/), save login details, and set it to run on boot by right-clicking it's icon in the system tray
- Install game clients (e.g. Steam) and a game or two.
- (Optional) Signup at [Duck DNS](https://www.duckdns.org/) and create a hostname for the private ZeroTier IP (NOT the public one).  If you really want a hostname for the dynamic public IP as well, create a secondary hostname and pick your favourite set of installation instructions.
- (Optional) Edit `default-allow-rdp` firewall rule in Cloud Console, change it's `Targets` to `Specified target tags` and add a target tag of `rdp-server`, so only instances with the network tag `rdp-server` have public RDP ports.  If you really need to RDP into the public IP address, add this network tag to a running instance.

## Notes
Once everything's setup, avoid using RDP since it'll disconnect your "physical" session on the virtual monitor - i.e. it'll show the windows lock screen, which upsets most streaming clients.  If you find yourself in this situation, connect using VNC to fix the issue or just use RDP anyway and restart the instance.

Whenever connecting to your instance, you should always use the ZeroTier IP. Only open up your instance's Public IP if that few extra milliseconds of software networking lag is worth foregoing basic network security.


## Starting over
-  Run `./destroy.sh` and answer yes to all prompts.  This might not delete everything;  check cloud console for any remaining resources.
