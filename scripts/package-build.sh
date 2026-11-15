#!/bin/bash
# package-build.sh - Pack a finished build into the archive the test Mac installs.
#
# Runs on the dev Mac (called by deploy.sh) and in CI (which publishes the
# archive as metalmix-dev.tar.gz in the dev-latest pre-release). Never runs on
# the test Mac. mm-update.command and deploy.sh both unpack this exact layout:
#
#   core/mmcore.dylib
#   core/build-commit.txt
#   bin/mmctl
#   shaders/bundled/  shaders/include/
#   presets/bundled/
#
# Usage: package-build.sh BUILD_DIR OUTPUT.tar.gz
#   BUILD_DIR  a CMake build folder, for example build/dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

[ $# -eq 2 ] || mm_die "Usage: package-build.sh BUILD_DIR OUTPUT.tar.gz"
build_dir="$1"
output="$2"

for required in "$build_dir/core/mmcore.dylib" "$build_dir/tools/mmctl/mmctl"; do
    [ -f "$required" ] || mm_die "Missing $required. Build first."
done

# Stage exactly the files the test Mac should get.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/core" "$stage/bin" "$stage/shaders" "$stage/presets"
cp "$build_dir/core/mmcore.dylib" "$stage/core/"
cp "$build_dir/tools/mmctl/mmctl" "$stage/bin/"
cp -R "$REPO_DIR/shaders/bundled" "$REPO_DIR/shaders/include" "$stage/shaders/"
cp -R "$REPO_DIR/presets/bundled" "$stage/presets/"
git -C "$REPO_DIR" rev-parse --short HEAD >"$stage/core/build-commit.txt" 2>/dev/null || true

# COPYFILE_DISABLE keeps macOS from adding ._ resource-fork files to the tar.
COPYFILE_DISABLE=1 tar -czf "$output" -C "$stage" .
mm_info "Packed build $(cat "$stage/core/build-commit.txt" 2>/dev/null || echo unknown) into $output"
