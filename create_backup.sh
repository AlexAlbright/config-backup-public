#!/opt/homebrew/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"

LIST_FILE="backup_items"
EXCLUDE_FILE="backup_excludes"
DEST_DIR="$REPO/backup"
LOG_FILE="$HOME/scripts/logs/create_backup.log"
MAX_LOG_LINES=2000

# Trim the log, then send all output to it
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LOG_LINES" ]; then
    tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
exec >> "$LOG_FILE" 2>&1

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

for f in "$LIST_FILE" "$EXCLUDE_FILE"; do
    if [ ! -f "$f" ]; then
        log "Error: $f does not exist."
        exit 1
    fi
done

# Load file into bash array, keeping only items that exist
readarray -t ITEMS < "$LIST_FILE"
SOURCES=()
for ITEM in "${ITEMS[@]}"; do
    [ -n "$ITEM" ] || continue
    if [ -e "$HOME/$ITEM" ]; then
        SOURCES+=("$ITEM")
    else
        log "Warning: ~/$ITEM does not exist."
    fi
done

# Mirror each item into backup/, keeping its path relative to $HOME.
# Exit 23/24 means some files changed or vanished mid-copy; carry on.
mkdir -p "$DEST_DIR"
rc=0
(cd "$HOME" && /usr/bin/rsync -rlpt --relative --delete --delete-excluded \
    --exclude-from="$REPO/$EXCLUDE_FILE" "${SOURCES[@]}" "$DEST_DIR/") || rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 23 ] && [ "$rc" -ne 24 ]; then
    log "Error: rsync failed with exit $rc, not committing."
    exit 1
fi

# Refuse to commit a backup that lost any item that exists in $HOME
for ITEM in "${SOURCES[@]}"; do
    if [ ! -e "$DEST_DIR/$ITEM" ]; then
        log "Error: backup/$ITEM is missing, not committing."
        exit 1
    fi
done

# commit changes to repository, only if something changed
git add --all
if ! git diff --cached --quiet; then
    git commit -q -m "Automated config sync"
    log "Committed $(git rev-parse --short HEAD): $(git show --shortstat --format= HEAD | xargs)"
fi

# push anything not yet on origin, so a failed push is retried next run
if [ -n "$(git rev-list '@{u}..HEAD')" ]; then
    if git push -q origin; then
        log "Pushed."
    else
        log "Error: push failed, will retry next run."
        exit 1
    fi
fi
