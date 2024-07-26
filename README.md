
# config-backup

## Automated backup of home folder configruation items

I've been on a bit of a tear learning more powerful configruation management tools, once of which is Ansible.
Now Ansible is excellent for host configruation but it clearly works best if you have personalized configurations stored somewhere.
After doing some digging and seeing what others have chosen to do I decided to use a combination of scripting, as well as the macOS system orchestration tool `launchd`.
This repo contains a few main pieces, the rest of the files here are simply the backed up configruation files. I store these at the root of this directory for simplicity, however this could be organized better.

Anyway... as for how this works, there are 4 main components.
1. backup_items - files/directories you wish to back up, one per line
2. create_backup.sh - copies all of the files/directories from backup_items into it's current directory
3. sync_configs.sh - helper script, added to `launchd` to monitor for changes to files in `backup_items` once detected, it calls `create_backup` 
4. com.alexalbright.auto-sync-configs - This is the plist file that contains instructions for `launchd` to run `sync_configs`

## Prerequisites

This was designed for macOS sonoma 14.5, but will likely work on older macOS versions
There are a few other considerations and assumptions made if you are trying to use this 
1. macOS Homebrew is configured - you'll notice the scripts reference homebrew binaries instead of built in ones
    1. `brew install bash` - bash v4 or higher is needed for `readarray`
    2. `brew install fswatch` - used to monitor for file changes
    3. `brew install git` - included with macos but for good measure


## Usage

To use this script, clone the repo into a place where it is exectuable by `launchd`
I chose, `~/scripts/config-backup/`, if you choose a main folder such as `~/Documents/` you might have issues!
When building this, for some reason, `launchd` had permissions issues with accessing this repo when it was located at `~/Documents/workspace/scripts`.

1. Customize your `backup_items` file, include a list of items from your home directory
2. Edit `com.alexalbright.auto-sync-configs`
    1. change the filename and username to yours
    2. change the program arguments to the location of `sync_configs.sh`
    3. change the stdout and stderr path 
    4. change the working directory to where this repo is cloned
3. Copy `com.$USER.auto-sync-configs` to `~/Library/LaunchAgents/`
4. ` cd ~/Library/LaunchAgents`
5. Add to `launchd` with `launchctl load com.$USER.auto-sync-config.plist`
6. Check to see if it's running correctly with `launchctl list | grep auto-sync`
7. If things are operating normally you'll see something like `64743   0       com.alexalbright.auto-sync-config`
8. If that second number is anything other than `0`, something is wrong, check the stderr log file
9. To remove this from `launchd` run `launchctl bootout gui/$(id -u) com.alexalbright.auto-sync-config.plist`, then you can run the load command once it's fixed
