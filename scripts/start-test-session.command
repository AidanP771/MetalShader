#!/bin/bash
# start-test-session.command - Double-click this on the test Mac before every
# MetalMix test session.
#
# It backs up the Sims saves (small, deduplicated, size-capped; see
# backup-sims-saves.sh), then shows a short checklist. If the backup fails, do
# not test until it works.

cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/lib/common.sh
. ./lib/common.sh

finish() {
    echo
    read -r -p "Press Return to close this window. " _
    exit "$1"
}

echo "MetalMix test session"
echo "====================="
echo

if mm_game_is_running; then
    mm_warn "The Sims 4 is running. Quit the game, then double-click this again."
    finish 1
fi

if ! ./backup-sims-saves.sh; then
    echo
    mm_warn "The save backup failed. Do not start testing until it works."
    finish 1
fi

echo
mm_info "Before you start the game:"
mm_note "1. In the EA app, make sure auto-update is off for The Sims 4."
mm_note "2. Game version installed: $(mm_game_version)"
if [ -f "$MM_SUPPORT_DIR/DISABLED" ]; then
    mm_note "3. MetalMix is currently DISABLED (the DISABLED file exists)."
else
    mm_note "3. MetalMix is enabled. Hold Option while the game starts to skip it once."
fi
if [ -f "$MM_SUPPORT_DIR/launching" ]; then
    mm_note "4. Crash marker present: the last launch did not reach healthy frames."
fi
echo
mm_info "After testing, double-click mm-report.command to send logs to the dev Mac."
finish 0
