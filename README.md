
# config-backup

## Automated backup of home folder configuration items

I've been on a bit of a tear learning more powerful configuration management tools, one of which is Ansible.
Now Ansible is excellent for host configuration but it clearly works best if you have personalized configurations stored somewhere.
After doing some digging and seeing what others have chosen to do I decided to use a combination of scripting, as well as the macOS system orchestration tool `launchd`.
This repo contains a few main pieces; the backed up configuration files themselves land in `backup/`, with their paths kept relative to your home directory (so `~/.ssh/config` becomes `backup/.ssh/config`).

Anyway... as for how this works, there are 5 main components.
1. `backup_items` - files/directories you wish to back up, one per line, relative to `~`
2. `backup_excludes` - rsync exclude patterns for things not worth backing up (plugin and extension folders you can reinstall, sockets, nested `.git` folders, `.DS_Store`). A leading `/` anchors the pattern to `~`
3. `create_backup.sh` - mirrors every item from `backup_items` into `backup/` with `rsync --delete`, so files you delete or rename locally are removed from the backup too. It commits only when something actually changed, and pushes whenever the local branch is ahead of origin, so a failed push is retried on the next run
4. `sync_configs.sh` - helper script, added to `launchd` to monitor for changes to files in `backup_items`. Once detected, it waits 30 seconds for things to settle (so a burst of saves becomes one commit) and then calls `create_backup.sh`
5. `com.alexalbright.auto-sync-config.plist` - This is the plist file that contains instructions for `launchd` to run `sync_configs.sh`

### Safety checks

Because this commits and pushes on its own, `create_backup.sh` refuses to commit if rsync fails, or if any item that exists in your home directory is missing from `backup/` afterwards. That way a bad exclude pattern can't push a commit that deletes your whole backup.

## Prerequisites

This was designed for macOS Sonoma 14.5, but will likely work on older macOS versions.
There are a few other considerations and assumptions made if you are trying to use this:
1. macOS Homebrew is configured - you'll notice the scripts reference homebrew binaries instead of built in ones
    1. `brew install bash` - bash v4 or higher is needed for `readarray`
    2. `brew install fswatch` - used to monitor for file changes
    3. `brew install git` - included with macOS but for good measure
2. `rsync` - the one built into macOS (`/usr/bin/rsync`) is used. Note it's `openrsync`, which doesn't understand the `/./` relative-path marker, which is why the script `cd`s into `~` first
3. Push access to your remote over SSH from a background process (an SSH key that's loaded in your agent, or one without a passphrase)

**Make your backup repo private.** Files like `.ssh/config` and `.aws/config` say a lot about your machines and accounts, and everything in `backup_items` gets pushed wherever `origin` points.

## Usage

To use this script, clone the repo into a place where it is executable by `launchd`.
I chose `~/scripts/config-backup/`. If you choose a main folder such as `~/Documents/` you might have issues!
macOS privacy protections (TCC) block `launchd` jobs from reading `~/Documents`, `~/Desktop` and `~/Downloads`, which is why it had permission issues when it was located at `~/Documents/workspace/scripts`.

1. Customize your `backup_items` file, include a list of items from your home directory
2. Customize `backup_excludes` for anything large or reinstallable inside those items
3. Edit `com.alexalbright.auto-sync-config.plist`
    1. change the filename, label and username to yours
    2. change the program arguments to the location of `sync_configs.sh`
    3. change the stdout and stderr path
    4. change the working directory to where this repo is cloned
4. Create the log folder: `mkdir -p ~/scripts/logs`
5. Copy `com.$USER.auto-sync-config.plist` to `~/Library/LaunchAgents/`
6. Add it to `launchd` with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.$USER.auto-sync-config.plist`
7. Check to see if it's running correctly with `launchctl list | grep auto-sync`
8. If things are operating normally you'll see something like `64743   0       com.alexalbright.auto-sync-config`
9. If that second number is anything other than `0`, something is wrong, check the logs (below)
10. To remove it from `launchd` run `launchctl bootout gui/$(id -u)/com.$USER.auto-sync-config`, then run the bootstrap command again once it's fixed. Stop it this way before editing the scripts, too

## Logs

- `~/scripts/logs/create_backup.log` - one timestamped line per commit, push, warning or error. It's trimmed to the last 2000 lines automatically
- The stdout/stderr files from the plist only catch output from `sync_configs.sh` and `fswatch` itself

## Removing an item

Taking an item out of `backup_items` stops it being synced, but `rsync --delete` only cleans up inside items that are still listed. Remove the old copy yourself with `git rm -r backup/<item>`.
