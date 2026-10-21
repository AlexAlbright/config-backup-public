#!/opt/homebrew/bin/bash

DIR_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR_PATH" || exit 1

LIST_FILE="backup_items"

# Seconds to wait after a change so a burst of saves becomes one backup
LATENCY=30

# Check if the list file exists
if [ ! -f "$LIST_FILE" ]; then
    echo "Error: List file $LIST_FILE does not exist."
    exit 1
fi

# read file into list, adding the home directory prefix and skipping blank lines
files_to_watch=()
while IFS= read -r e; do
    [ -n "$e" ] && files_to_watch+=("$HOME/$e")
done < "$LIST_FILE"

# use fswatch to watch each file for changes then resync them if changed;
# skip churn in excluded plugin, extension and socket paths
/opt/homebrew/bin/fswatch -o -l "$LATENCY" \
    -e '/\.vscode/extensions/' \
    -e '/\.vim/plugged/' \
    -e '/\.config/raycast/(extensions|node-compile-cache)/' \
    -e '/\.DS_Store$' \
    -e 'sock(et)?$' \
    "${files_to_watch[@]}" | xargs -n1 "$DIR_PATH/create_backup.sh"
