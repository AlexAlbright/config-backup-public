#!/opt/homebrew/bin/bash

LIST_FILE="backup_items"

# Check if the list file exists
if [ ! -f "$LIST_FILE" ]; then
    echo "Error: List file $LIST_FILE does not exist."
    exit 1
fi

# Load file into bash array
readarray -t ITEMS_TO_COPY < "${LIST_FILE}"

# Get the current script location
DEST_DIR="$(pwd)/backup"

# Function to copy each file or directory
copy_files() {
    for ITEM in "${ITEMS_TO_COPY[@]}"; do
      if [ -e "$HOME/$ITEM" ]; then
        cp -r "$HOME/$ITEM" "$DEST_DIR"
            echo "Copied $HOME/$ITEM to $DEST_DIR"
        else
            echo "Error: $ITEM does not exist."
        fi
    done
}

# Call the function
copy_files

# Remove git subdirectories
find . -mindepth 2 -type d -name ".git" -exec rm -rf {} +

# commit changes to repository
git add --all
git commit -m "Automated config sync"
git push origin
