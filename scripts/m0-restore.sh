#!/bin/bash
# m0-restore.sh - Undo m0-resign.sh: put the game's original executable and
# signature back from the backup.
#
# Usage:
#   m0-restore.sh [--app PATH] [--from BACKUP_DIR]
#     --app PATH         app to restore (default: /Applications/The Sims 4.app)
#     --from BACKUP_DIR  a folder under backups/game/ (default: the newest one
#                        made for this app)
#
# If anything still looks wrong afterwards, use "Repair" on The Sims 4 in the
# EA app. That re-downloads any changed game files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

app="$MM_GAME_APP"
backup_dir=""

while [ $# -gt 0 ]; do
    case "$1" in
    --app)
        app="${2:?--app needs a path}"
        shift 2
        ;;
    --from)
        backup_dir="${2:?--from needs a folder}"
        shift 2
        ;;
    -h | --help)
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) mm_die "Unknown option: $1 (try --help)" ;;
    esac
done

mm_require_macos
app="${app%/}"
[ -d "$app/Contents" ] || mm_die "No app found at $app"
if mm_game_is_running; then
    mm_die "The Sims 4 is running. Quit it first."
fi

# Newest backup whose recorded app path matches this app.
if [ -z "$backup_dir" ]; then
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if [ "$(cat "$candidate/app-path.txt" 2>/dev/null)" = "$app" ]; then
            backup_dir="$candidate"
            break
        fi
    done <<EOF
$(find "$MM_SUPPORT_DIR/backups/game" -mindepth 1 -maxdepth 1 -type d -not -name '*.partial' \
        -exec stat -f '%m %N' {} \; 2>/dev/null | LC_ALL=C sort -rn | cut -d' ' -f2-)
EOF
fi

[ -n "$backup_dir" ] && [ -d "$backup_dir" ] || mm_die "No backup found for $app."

executable_name=$(cat "$backup_dir/executable-name.txt")
executable="$app/Contents/MacOS/$executable_name"

mm_info "Restoring $app from $backup_dir"
cp -p "$backup_dir/$executable_name" "$executable"
if [ -d "$backup_dir/_CodeSignature" ]; then
    rm -rf "$app/Contents/_CodeSignature"
    cp -Rp "$backup_dir/_CodeSignature" "$app/Contents/_CodeSignature"
fi

if codesign --verify --deep --strict --verbose=2 "$app"; then
    mm_info "Original signature restored and verified."
else
    mm_warn "The restored app does not verify. Use Repair on The Sims 4 in the EA app."
    exit 1
fi
