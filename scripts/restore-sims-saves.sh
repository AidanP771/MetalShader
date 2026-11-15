#!/bin/bash
# restore-sims-saves.sh - Put back saves from a backup made by backup-sims-saves.sh.
#
# Nothing is deleted. The current saves folder is moved aside to
# "saves.before-restore-<timestamp>" first, so a restore can itself be undone.
#
# Usage:
#   restore-sims-saves.sh                 list backups to choose from
#   restore-sims-saves.sh --latest        restore the newest backup
#   restore-sims-saves.sh --from FILE     restore a specific backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BACKUP_DIR="$MM_SUPPORT_DIR/backups/sims-saves"

mm_require_macos

backup_file=""
case "${1:-}" in
--latest)
    backup_file=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'sims-saves_*.tar.gz' 2>/dev/null |
        LC_ALL=C sort | sed -n '$p')
    ;;
--from)
    backup_file="${2:-}"
    ;;
-h | --help)
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
"")
    "$SCRIPT_DIR/backup-sims-saves.sh" --list
    mm_info "Run again with --latest or --from <file> to restore."
    exit 0
    ;;
*) mm_die "Unknown option: $1 (try --help)" ;;
esac

if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
    mm_die "Backup not found: ${backup_file:-none}"
fi
if mm_game_is_running; then
    mm_die "Quit The Sims 4 before restoring saves."
fi

mm_info "Restoring $(basename "$backup_file") into $MM_SIMS_USER_DIR"
if [ -f "${backup_file%.tar.gz}.txt" ]; then
    sed -n '1,7p' "${backup_file%.tar.gz}.txt" | sed 's/^/    /'
fi

if ! mm_confirm "Your current saves folder will be moved aside (not deleted) and replaced."; then
    mm_info "Cancelled. Nothing changed."
    exit 0
fi

if [ -d "$MM_SIMS_USER_DIR/saves" ]; then
    aside="$MM_SIMS_USER_DIR/saves.before-restore-$(mm_timestamp)"
    mv "$MM_SIMS_USER_DIR/saves" "$aside"
    mm_note "Current saves moved to $(basename "$aside")"
fi

tar -xzf "$backup_file" -C "$MM_SIMS_USER_DIR"
mm_info "Restore complete. Start the game and check your saves load."
mm_note "When you are happy, you can delete the saves.before-restore folder to free space."
