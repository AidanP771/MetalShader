#!/bin/bash
# mm-update.command - Double-click on the test Mac to install the latest dev
# build of MetalMix without the dev Mac being online.
#
# Downloads the "dev-latest" pre-release from GitHub (published by CI from M5;
# until then, use scripts/deploy.sh from the dev Mac), backs up the saves, then
# installs it into the MetalMix folder. Never touches the game itself.
#
# Setup: set MM_RELEASE_REPO to "owner/metalmix", or edit the default below.

cd "$(dirname "$0")" || exit 1
# shellcheck source=SCRIPTDIR/lib/common.sh
. ./lib/common.sh

RELEASE_REPO="${MM_RELEASE_REPO:-OWNER/metalmix}"
ASSET_URL="https://github.com/$RELEASE_REPO/releases/download/dev-latest/metalmix-dev.tar.gz"

finish() {
    echo
    read -r -p "Press Return to close this window. " _
    exit "$1"
}

if [ "$RELEASE_REPO" = "OWNER/metalmix" ]; then
    mm_warn "Set MM_RELEASE_REPO (or edit this script) to the GitHub repo first."
    finish 1
fi
if mm_game_is_running; then
    mm_warn "Quit The Sims 4 first."
    finish 1
fi

mm_info "Backing up saves"
./backup-sims-saves.sh || {
    mm_warn "Save backup failed. Not updating."
    finish 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mm_info "Downloading the latest dev build"
# curl downloads are not quarantined by Gatekeeper, unlike browser downloads.
if ! curl -fL --progress-bar -o "$work/build.tar.gz" "$ASSET_URL"; then
    mm_warn "Download failed from $ASSET_URL"
    finish 1
fi

mkdir -p "$work/build"
tar -xzf "$work/build.tar.gz" -C "$work/build" || {
    mm_warn "The download is damaged."
    finish 1
}

dest="$MM_SUPPORT_DIR"
mkdir -p "$dest/core" "$dest/bin" "$dest/shaders" "$dest/presets"
mv -f "$work/build/core/mmcore.dylib" "$dest/core/mmcore.dylib"
mv -f "$work/build/core/build-commit.txt" "$dest/core/build-commit.txt" 2>/dev/null || true
mv -f "$work/build/bin/mmctl" "$dest/bin/mmctl"
for part in shaders/bundled shaders/include presets/bundled; do
    rm -rf "${dest:?}/$part"
    mv "$work/build/$part" "$dest/$part"
done

mm_info "Installed build $(cat "$dest/core/build-commit.txt" 2>/dev/null || echo unknown)."
finish 0
