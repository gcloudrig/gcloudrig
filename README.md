gcloudrig
---------

Setup:
- Set project name and any other variables in `./globals.sh`
- Run `./setup.sh`

First run:
- Run `./scale-up.sh`
- RDP to the instance using the credentials provided by the script.  Alternatively, set password & download the RDP file direct from cloud console.
- Install [GRID® drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/add-gpus#installing_gridwzxhzdk37_drivers_for_virtual_workstations)
- Download & run [Autologon](https://docs.microsoft.com/en-au/sysinternals/downloads/autologon)
- Install [ZeroTier](https://zerotier.com/), create/join a network, and set it to run on boot by right-clicking it's icon in the system tray
- Install [TightVNC](https://www.tightvnc.com/) server and lock it down to zerotier's IP range  (e.g. `allow 10.147.17.0-10.147.17.255`; `deny 0.0.0.0-255.255.255`).  You should still set a password.
- Test TightVNC
- Reboot to finish GPU driver installation.
- Login with TightVNC, set display to "Show only on Monitor 2" and give it an appropriate screen resolution (this is to disable the primary 640x480 screen, which gives Parsec headaches)
- Install [Parsec](https://parsecgaming.com/), save login details, and set it to run on boot by right-clicking it's icon in the system tray
- Install game clients (e.g. Steam) and games
- (Optional) Edit `default-allow-rdp` firewall rule in cloud console, change it's Targets to `Specified target tags`, add a target tag of `rdp-server`.  If you ever need to RDP to the public IP of a running instance, edit it and add the network label `rdp-server`.
- (Optional) Signup at [Duck DNS](https://www.duckdns.org/) and create a hostname for the private ZeroTier IP (NOT the public one).  Use this hostname when using RDP, VNC, etc.
- Run `./scale-down.sh` to stop.

Locally:
- Install [ZeroTier](https://zerotier.com/), create/join the same network.  

Subsequent runs:
-  Run `./scale-up.sh` to start
-  Connect with Parsec or other streaming client of your choice.  Use VNC with ZeroTier IP if you run into problems.
-  Run `./scale-down.sh` to stop 

Starting over
-  Run `./destroy.sh` and answer yes to all prompts