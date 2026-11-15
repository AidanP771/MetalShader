#!/bin/bash
# deploy.sh - Build on the dev Mac and copy MetalMix to the test Mac over SSH.
#
# Copies the core, mmctl, bundled shaders and bundled presets into the test
# Mac's ~/Library/Application Support/MetalMix/. Never touches the game, the
# saves, or anything in shaders/user/ or presets/user/.
#
# The core is swapped in with an atomic rename, so a running game keeps the
# copy it already loaded; relaunch the game to pick up a new core. Shader and
# preset changes hot reload without a relaunch (from M3).
#
# Usage:
#   deploy.sh [--no-build] [--host HOST]
#     --host HOST   SSH host alias (default: test-mac, or $MM_TEST_HOST)
#     --no-build    deploy what is already in build/dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

host="$MM_TEST_HOST"
build=1
while [ $# -gt 0 ]; do
    case "$1" in
    --host)
        host="${2:?--host needs a value}"
        shift 2
        ;;
    --no-build)
        build=0
        shift
        ;;
    -h | --help)
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) mm_die "Unknown option: $1 (try --help)" ;;
    esac
done

BUILD_DIR="$REPO_DIR/build/dev"

if [ "$build" -eq 1 ]; then
    mm_info "Building (dev preset)"
    cmake --preset dev >/dev/null
    cmake --build --preset dev
fi

# Same archive CI publishes, so deploy.sh and mm-update.command install alike.
archive_dir=$(mktemp -d)
trap 'rm -rf "$archive_dir"' EXIT
archive="$archive_dir/metalmix-dev.tar.gz"
"$SCRIPT_DIR/package-build.sh" "$BUILD_DIR" "$archive"

mm_info "Copying to $host"
scp -q "$archive" "$host:/tmp/metalmix-deploy.tgz"

# Unpack on the test Mac. Paths contain spaces, so all quoting happens there.
ssh "$host" 'bash -s' <<'REMOTE'
set -euo pipefail
dest="$HOME/Library/Application Support/MetalMix"
incoming="$dest/.incoming"
rm -rf "$incoming"
mkdir -p "$incoming" "$dest/core" "$dest/bin" "$dest/shaders" "$dest/presets"
tar -xzf /tmp/metalmix-deploy.tgz -C "$incoming"
rm -f /tmp/metalmix-deploy.tgz

# Atomic renames: a running game keeps the core it already mapped.
mv -f "$incoming/core/mmcore.dylib" "$dest/core/mmcore.dylib"
mv -f "$incoming/core/build-commit.txt" "$dest/core/build-commit.txt" 2>/dev/null || true
mv -f "$incoming/bin/mmctl" "$dest/bin/mmctl"

# Replace bundled content only; user shaders and presets are never touched.
for part in shaders/bundled shaders/include presets/bundled; do
    rm -rf "$dest/$part"
    mv "$incoming/$part" "$dest/$part"
done
rm -rf "$incoming"
echo "Deployed build $(cat "$dest/core/build-commit.txt" 2>/dev/null || echo unknown) to $dest"
REMOTE

mm_info "Done. Relaunch the game to load the new core."
