#!/bin/bash
# backup-sims-saves.sh - Back up The Sims 4 saves before a MetalMix test session.
#
# Runs automatically from start-test-session.command, m0-resign.sh and
# mm-update.command. Safe to run by hand any time the game is closed.
#
# What it backs up (kept small on purpose):
#   always:            saves/*.save, Options.ini, GameVersion.txt
#   with --with-tray:  Tray/ (households, lots and rooms in the library)
#   never:             the game's own .ver0 to .ver4 save copies, Mods,
#                      caches, thumbnails, screenshots, recorded videos
#
# How it stays small:
#   - Skips the backup when nothing changed since the last one.
#   - Compresses each backup (tar.gz).
#   - Keeps the newest MM_BACKUP_KEEP backups (default 3).
#   - Then deletes the oldest while the total is over MM_BACKUP_MAX_MB
#     (default 2048), but never the newest backup.
#   - Refuses to start when the disk is nearly full.
#
# Backups live in ~/Library/Application Support/MetalMix/backups/sims-saves/,
# outside ~/Documents so iCloud never uploads them.
#
# Usage:
#   backup-sims-saves.sh              back up if anything changed
#   backup-sims-saves.sh --list       show existing backups and total size
#   backup-sims-saves.sh --dry-run    show what would be backed up, change nothing
#   backup-sims-saves.sh --with-tray  include the Tray folder
#   backup-sims-saves.sh --force      back up even if the game is running
#
# Restore with scripts/restore-sims-saves.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

KEEP_COUNT="${MM_BACKUP_KEEP:-3}"
MAX_TOTAL_MB="${MM_BACKUP_MAX_MB:-2048}"
FREE_SPACE_MARGIN_MB=1024 # Always leave at least this much free after a backup.
BACKUP_DIR="$MM_SUPPORT_DIR/backups/sims-saves"
FINGERPRINT_FILE="$BACKUP_DIR/last-fingerprint.txt"

with_tray=0
force=0
dry_run=0
list_only=0

print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
    case "$arg" in
    --with-tray) with_tray=1 ;;
    --force) force=1 ;;
    --dry-run) dry_run=1 ;;
    --list) list_only=1 ;;
    -h | --help)
        print_help
        exit 0
        ;;
    *) mm_die "Unknown option: $arg (try --help)" ;;
    esac
done

mm_require_macos

# ---- Helpers ---------------------------------------------------------------

# Existing backups, oldest first. Names start with a sortable timestamp.
list_backups_oldest_first() {
    if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -maxdepth 1 -type f -name 'sims-saves_*.tar.gz' | LC_ALL=C sort
    fi
}

file_size_bytes() { stat -f '%z' "$1"; }

total_backup_bytes() {
    local total=0 file
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        total=$((total + $(file_size_bytes "$file")))
    done <<EOF
$(list_backups_oldest_first)
EOF
    echo "$total"
}

backup_count() {
    list_backups_oldest_first | grep -c . || true
}

show_backups() {
    local file count
    count=$(backup_count)
    if [ "$count" -eq 0 ]; then
        mm_info "No save backups yet."
        return
    fi
    mm_info "Save backups in $BACKUP_DIR (oldest first):"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        mm_note "$(basename "$file")  $(mm_human_size "$(file_size_bytes "$file")")"
    done <<EOF
$(list_backups_oldest_first)
EOF
    mm_note "Total: $(mm_human_size "$(total_backup_bytes)") in $count backup(s)" \
        "(limits: newest $KEEP_COUNT, $MAX_TOTAL_MB MB)"
}

# Relative paths of every file to back up, one per line, sorted.
collect_files() {
    (
        cd "$MM_SIMS_USER_DIR"
        {
            if [ -d saves ]; then
                find saves -maxdepth 1 -type f -name '*.save'
            fi
            for name in Options.ini GameVersion.txt; do
                if [ -f "$name" ]; then
                    echo "$name"
                fi
            done
            if [ "$with_tray" -eq 1 ] && [ -d Tray ]; then
                find Tray -type f
            fi
        } | LC_ALL=C sort
    )
}

# A hash of every file's name, size and modification time. If it matches the
# last backup's, nothing has changed and the backup is skipped.
fingerprint_of() {
    local list_file="$1"
    (
        cd "$MM_SIMS_USER_DIR"
        while IFS= read -r path; do
            stat -f '%z %m %N' "$path"
        done <"$list_file"
        echo "tray=$with_tray"
    ) | shasum -a 256 | awk '{ print $1 }'
}

# Deletes old backups: first down to KEEP_COUNT, then oldest-first while over
# MAX_TOTAL_MB. Never deletes the newest backup.
prune_backups() {
    local oldest max_bytes
    while [ "$(backup_count)" -gt "$KEEP_COUNT" ]; do
        oldest=$(list_backups_oldest_first | sed -n 1p)
        mm_note "Removing old backup $(basename "$oldest") (keeping newest $KEEP_COUNT)"
        rm -f "$oldest" "${oldest%.tar.gz}.txt"
    done

    max_bytes=$((MAX_TOTAL_MB * 1024 * 1024))
    while [ "$(backup_count)" -gt 1 ] && [ "$(total_backup_bytes)" -gt "$max_bytes" ]; do
        oldest=$(list_backups_oldest_first | sed -n 1p)
        mm_note "Removing old backup $(basename "$oldest") (total over $MAX_TOTAL_MB MB)"
        rm -f "$oldest" "${oldest%.tar.gz}.txt"
    done

    if [ "$(total_backup_bytes)" -gt "$max_bytes" ]; then
        mm_warn "The newest backup alone is over $MAX_TOTAL_MB MB. Raise MM_BACKUP_MAX_MB or" \
            "back up without --with-tray."
    fi
}

# ---- Main ------------------------------------------------------------------

if [ "$list_only" -eq 1 ]; then
    show_backups
    exit 0
fi

if [ ! -d "$MM_SIMS_USER_DIR" ]; then
    mm_die "Sims user folder not found at $MM_SIMS_USER_DIR. Set MM_SIMS_USER_DIR if it lives elsewhere."
fi

if mm_game_is_running && [ "$force" -eq 0 ]; then
    mm_die "The Sims 4 is running. Quit it first, so a save being written is not captured" \
        "half-finished. (--force overrides this.)"
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
file_list="$work_dir/files.txt"
collect_files >"$file_list"

file_count=$(grep -c . "$file_list" || true)
if [ "$file_count" -eq 0 ]; then
    mm_warn "No saves found in $MM_SIMS_USER_DIR/saves. Nothing to back up."
    exit 0
fi

source_bytes=0
while IFS= read -r path; do
    source_bytes=$((source_bytes + $(file_size_bytes "$MM_SIMS_USER_DIR/$path")))
done <"$file_list"

mm_info "Backing up $file_count file(s), $(mm_human_size "$source_bytes") before compression."
if [ "$with_tray" -eq 0 ]; then
    mm_note "Tray is not included (add --with-tray to include it)."
fi

fingerprint=$(fingerprint_of "$file_list")
if [ -f "$FINGERPRINT_FILE" ] && [ "$(head -n 1 "$FINGERPRINT_FILE")" = "$fingerprint" ]; then
    mm_info "Nothing changed since the last backup ($(sed -n 2p "$FINGERPRINT_FILE")). Skipping."
    show_backups
    exit 0
fi

if [ "$dry_run" -eq 1 ]; then
    mm_info "Dry run: these files would be backed up:"
    sed 's/^/    /' "$file_list"
    show_backups
    exit 0
fi

mkdir -p "$BACKUP_DIR"

source_mb=$((source_bytes / 1024 / 1024))
free_mb=$(mm_free_space_mb "$BACKUP_DIR")
if [ "$free_mb" -lt $((source_mb + FREE_SPACE_MARGIN_MB)) ]; then
    mm_die "Only $free_mb MB free. Need about $((source_mb + FREE_SPACE_MARGIN_MB)) MB" \
        "(saves plus a $FREE_SPACE_MARGIN_MB MB margin). Free some space first."
fi

stamp=$(mm_timestamp)
archive="$BACKUP_DIR/sims-saves_${stamp}.tar.gz"
partial="$archive.partial"

# Write to a temporary name and rename only after it verifies, so a failed or
# interrupted backup never looks like a good one.
tar -czf "$partial" -C "$MM_SIMS_USER_DIR" -T "$file_list"
if ! tar -tzf "$partial" >/dev/null; then
    rm -f "$partial"
    mm_die "The new backup failed verification and was deleted. Do not test until this works."
fi
mv "$partial" "$archive"

cat >"${archive%.tar.gz}.txt" <<EOF
Backup:       $(basename "$archive")
Created:      $(date)
Game version: $(mm_game_version)
Files:        $file_count
Size before:  $(mm_human_size "$source_bytes")
Size after:   $(mm_human_size "$(file_size_bytes "$archive")")
Tray:         $([ "$with_tray" -eq 1 ] && echo included || echo not included)

Files in this backup:
$(cat "$file_list")
EOF

printf '%s\n%s\n' "$fingerprint" "$(basename "$archive")" >"$FINGERPRINT_FILE"

mm_info "Saved $(basename "$archive") ($(mm_human_size "$(file_size_bytes "$archive")"))."
prune_backups
show_backups
