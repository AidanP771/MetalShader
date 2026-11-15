#!/bin/bash
# mm-report.command - Double-click on the test Mac after a test session. It
# collects MetalMix logs, screenshots and crash reports into the private
# metalmix-testbench repo and pushes them, so the dev Mac can git pull them.
#
# Kept small: only the last few hours of logs, screenshots and crash reports
# from today, and any single file over 50 MB is skipped.
#
# Setup (once): clone the private testbench repo to ~/metalmix-testbench with a
# deploy key that can only push to that repo. See docs/dev-setup.md.

cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/lib/common.sh
. ./lib/common.sh

TESTBENCH_DIR="${MM_TESTBENCH_DIR:-$HOME/metalmix-testbench}"
MAX_FILE_MB=50
LOG_WINDOW="${MM_REPORT_LOG_WINDOW:-4h}"

finish() {
    echo
    read -r -p "Press Return to close this window. " _
    exit "$1"
}

if [ ! -d "$TESTBENCH_DIR/.git" ]; then
    mm_warn "No testbench repo at $TESTBENCH_DIR. See docs/dev-setup.md (Async testing)."
    finish 1
fi

read -r -p "One line about this session (what you tested, anything odd): " note

stamp=$(mm_timestamp)
dest="$TESTBENCH_DIR/reports/${stamp}_$(scutil --get ComputerName 2>/dev/null | tr ' ' '-')"
mkdir -p "$dest"

# Copies a file unless it is too big. Keeps the repo from ballooning.
copy_small() {
    local size_mb
    size_mb=$(($(stat -f '%z' "$1") / 1024 / 1024))
    if [ "$size_mb" -gt "$MAX_FILE_MB" ]; then
        mm_warn "Skipping $(basename "$1") ($size_mb MB is over $MAX_FILE_MB MB)."
        return
    fi
    cp -p "$1" "$2"
}

mm_info "Collecting the session report"

{
    echo "Note:         $note"
    echo "Date:         $(date)"
    echo "macOS:        $(sw_vers -productVersion)"
    echo "Chip:         $(sysctl -n machdep.cpu.brand_string)"
    echo "Game version: $(mm_game_version)"
    echo "Core build:   $(cat "$MM_SUPPORT_DIR/core/build-commit.txt" 2>/dev/null || echo unknown)"
    echo "Disabled:     $([ -f "$MM_SUPPORT_DIR/DISABLED" ] && echo yes || echo no)"
    echo "Crash marker: $(cat "$MM_SUPPORT_DIR/launching" 2>/dev/null || echo none)"
} >"$dest/session.txt"

log show --predicate "subsystem == \"$MM_LOG_SUBSYSTEM\"" --last "$LOG_WINDOW" --style compact \
    >"$dest/metalmix-log.txt" 2>/dev/null || mm_warn "Could not read the system log."

if [ -d "$HOME/Library/Logs/MetalMix" ]; then
    mkdir -p "$dest/logs"
    find "$HOME/Library/Logs/MetalMix" -type f -mtime -1 | while IFS= read -r file; do
        copy_small "$file" "$dest/logs/"
    done
fi

if [ -d "$MM_SUPPORT_DIR/passlogs" ]; then
    mkdir -p "$dest/passlogs"
    find "$MM_SUPPORT_DIR/passlogs" -type f -mtime -1 | while IFS= read -r file; do
        copy_small "$file" "$dest/passlogs/"
    done
fi

if [ -d "$HOME/Pictures/MetalMix" ]; then
    mkdir -p "$dest/screenshots"
    find "$HOME/Pictures/MetalMix" -type f -name '*.png' -mtime -1 | while IFS= read -r file; do
        copy_small "$file" "$dest/screenshots/"
    done
fi

mkdir -p "$dest/crashes"
find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f -name 'The Sims 4*.ips' -mtime -1 |
    while IFS= read -r file; do
        copy_small "$file" "$dest/crashes/"
    done

# Drop empty folders so the report only shows what exists.
find "$dest" -type d -empty -delete

mm_info "Pushing to the testbench repo"
if git -C "$TESTBENCH_DIR" add reports &&
    git -C "$TESTBENCH_DIR" commit -q -m "Test session $stamp: $note" &&
    git -C "$TESTBENCH_DIR" push -q; then
    mm_info "Report sent: reports/$(basename "$dest")"
    finish 0
fi

mm_warn "Could not push. The report is saved in $dest; try again later."
finish 1
