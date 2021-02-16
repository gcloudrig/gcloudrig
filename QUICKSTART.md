
To setup a new rig:
$ ./setup.sh

To launch an existing rig:
$ ./scale-up.sh

To stop and save a running rig:
$ ./scale-down.sh

If the scripts aren't working, ensure you have an active project:
$ gcloud config set project $DEVSHELL_PROJECT_ID

For information on how to connect to your rig, view the full readme at:
https://github.com/gcloudrig/gcloudrig/blob/master/README.md
