#!/bin/bash
# pull-crashes.sh - Copy recent crash reports for the game and test host from
# the test Mac to reports/crashes/ on the dev Mac. (reports/ is git-ignored.)
#
# Usage: pull-crashes.sh [--host HOST] [--days N]   (defaults: test-mac, 3)
#
# Symbolicate with the matching dSYM from the build whose commit is in
# ~/Library/Application Support/MetalMix/core/build-commit.txt on the test Mac.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

host="$MM_TEST_HOST"
days=3
while [ $# -gt 0 ]; do
    case "$1" in
    --host)
        host="${2:?}"
        shift 2
        ;;
    --days)
        days="${2:?}"
        shift 2
        ;;
    *) mm_die "Unknown option: $1" ;;
    esac
done

# $days is pasted into the remote command line, so only allow whole numbers.
case "$days" in
'' | *[!0-9]*) mm_die "--days must be a whole number of days, got: $days" ;;
esac

dest="$REPO_DIR/reports/crashes/$(mm_timestamp)"
mkdir -p "$dest"

# The remote side lists matching files and streams them back as one tar.
# shellcheck disable=SC2029 # $days expands here on purpose; it is checked above.
ssh "$host" "bash -s -- $days" <<'REMOTE' | tar -xzf - -C "$dest"
set -euo pipefail
cd "$HOME/Library/Logs/DiagnosticReports"
find . -maxdepth 1 -type f \( -name 'The Sims 4*.ips' -o -name 'testhost*.ips' \) -mtime "-$1" \
    > /tmp/metalmix-crashes.txt
if [ -s /tmp/metalmix-crashes.txt ]; then
    tar -czf - -T /tmp/metalmix-crashes.txt
else
    tar -czf - -T /dev/null
fi
rm -f /tmp/metalmix-crashes.txt
REMOTE

count=$(find "$dest" -type f | grep -c . || true)
if [ "$count" -eq 0 ]; then
    rmdir "$dest"
    mm_info "No crash reports from the last $days day(s)."
else
    mm_info "Pulled $count crash report(s) into $dest"
fi
