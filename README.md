gcloudrig
---------

Usage:
- Set project name and any other variables in `./globals.sh`
- Run `./setup.sh` to create a usable image, instance template and instance group
- Create a disk (save the name as `GAMESDISK` variable in `./globals.sh`)
- Run `./scale-up.sh`
- Use the above credentials to RDP to the instance
- Install 'GRID® drivers for virtual workstations'
- Enable auto login (start > run > 'control userpasswords2')
- Install parsec, login, and set it to run on boot (right-click in the system tray)
- Install zerotier and join a network (create a new one if you haven't used zerotier before)
- Install TightVNC and lock it down to zerotier's IP range for difficult times
- Reboot and try connect with parsec
- Run `./scale-down.sh`
