#!/bin/bash
# inject-testhost.sh - Run the test host with the freshly built MetalMix
# injected. Dev Mac only.
#
# Uses DYLD_INSERT_LIBRARIES to load the loader (the same file the game will
# load via its patched load command) and MM_CORE_PATH so the loader uses the
# core from build/dev instead of the installed one.
#
# Watch the logs in another terminal:
#   log stream --predicate 'subsystem == "io.metalmix"' --level debug
#
# Usage: inject-testhost.sh [extra environment, e.g. MTL_DEBUG_LAYER=1]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BUILD_DIR="$REPO_DIR/build/dev"
loader="$BUILD_DIR/loader/mmloader.dylib"
core="$BUILD_DIR/core/mmcore.dylib"
app="$BUILD_DIR/testhost/testhost.app/Contents/MacOS/testhost"

for required in "$loader" "$core" "$app"; do
    [ -e "$required" ] || mm_die "Missing $required. Run: cmake --preset dev && cmake --build --preset dev"
done

if codesign -dv "$app" 2>&1 | grep -q 'flags=.*runtime'; then
    mm_die "This test host was built with MM_TESTHOST_HARDENED=ON, which ignores" \
        "DYLD_INSERT_LIBRARIES. Rebuild with -DMM_TESTHOST_HARDENED=OFF."
fi

mm_info "Launching the test host with MetalMix injected"
exec env "$@" MM_CORE_PATH="$core" DYLD_INSERT_LIBRARIES="$loader" "$app"
