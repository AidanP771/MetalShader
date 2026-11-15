# shellcheck shell=bash
# common.sh - Shared settings and helpers for MetalMix scripts.
#
# Source this file; do not run it. Every script in scripts/ uses it so paths
# and messages stay consistent. Works with macOS's built-in bash 3.2.
#
# Every path can be overridden with an environment variable, which is how the
# scripts are pointed at a test copy instead of the real game.

MM_SUPPORT_DIR="${MM_SUPPORT_DIR:-$HOME/Library/Application Support/MetalMix}"
MM_SIMS_USER_DIR="${MM_SIMS_USER_DIR:-$HOME/Documents/Electronic Arts/The Sims 4}"
MM_GAME_APP="${MM_GAME_APP:-/Applications/The Sims 4.app}"
MM_TEST_HOST="${MM_TEST_HOST:-test-mac}"
# shellcheck disable=SC2034 # used by scripts that source this file
MM_LOG_SUBSYSTEM="io.metalmix"

mm_info() { printf '==> %s\n' "$*"; }
mm_note() { printf '    %s\n' "$*"; }
mm_warn() { printf 'Warning: %s\n' "$*" >&2; }
mm_die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

mm_require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        mm_die "This script only runs on macOS."
    fi
}

# True if The Sims 4 is running. Matches the game's executable path only, so
# the EA app and these scripts never count.
mm_game_is_running() {
    pgrep -f "The Sims 4.app/Contents/MacOS/" >/dev/null 2>&1
}

# Asks the user to type "yes". Returns 0 only for an exact "yes".
mm_confirm() {
    local answer
    printf '%s\nType yes to continue: ' "$1"
    read -r answer
    [ "$answer" = "yes" ]
}

# Formats a byte count for people: 1536 -> "1.5 KB".
mm_human_size() {
    awk -v bytes="$1" 'BEGIN {
        split("B KB MB GB TB", units, " ")
        i = 1
        while (bytes >= 1024 && i < 5) { bytes /= 1024; i++ }
        if (i == 1) printf "%d %s", bytes, units[i]
        else printf "%.1f %s", bytes, units[i]
    }'
}

# Timestamp safe for file names, and sortable: 2026-11-14_235900
mm_timestamp() { date +%Y-%m-%d_%H%M%S; }

# The game's version from its Info.plist, or "unknown".
mm_game_version() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
        "$MM_GAME_APP/Contents/Info.plist" 2>/dev/null || echo "unknown"
}

# Free space in the volume holding a path, in megabytes.
mm_free_space_mb() {
    df -k "$1" | awk 'NR == 2 { printf "%d", $4 / 1024 }'
}
