#!/opt/homebrew/bin/bash

LIST_FILE="backup_items"

DIR_PATH=`dirname "$0"`

# Check if the list file exists
if [ ! -f "$LIST_FILE" ]; then
    echo "Error: List file $LIST_FILE does not exist."
    exit 1
fi

# read file into list
readarray -t files_to_watch < "${LIST_FILE}"

# Add the home directory prefix to each element of the array
mapfile -t < <(for e in "${files_to_watch[@]}"; do echo "$HOME/${e}"; done)

# use fswatch to watch each file for changes then resync them if changed
/opt/homebrew/bin/fswatch -o "${MAPFILE[@]}" | xargs -n1 $DIR_PATH/create_backup.sh
