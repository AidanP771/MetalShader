#!/bin/bash
# m0-resign.sh - Milestone M0 spike: re-sign The Sims 4 ad hoc and see if the EA
# app still launches it. No MetalMix code is added; this only answers "does
# re-signing break anything?" before any other work depends on it.
#
# What it does, in order:
#   1. Refuses to run while the game is running.
#   2. Backs up the Sims saves (backup-sims-saves.sh). Stops if that fails.
#   3. Backs up the game executable and its signature, once per game build.
#   4. Re-signs the app ad hoc, keeping the game's own entitlements and adding
#      com.apple.security.cs.disable-library-validation (MetalMix needs it).
#   5. Verifies the new signature.
# Undo everything with scripts/m0-restore.sh.
#
# Usage:
#   m0-resign.sh [--app PATH] [--debuggable] [--dry-run]
#     --app PATH     app to re-sign (default: /Applications/The Sims 4.app)
#     --debuggable   also add get-task-allow so lldb can attach (dev only)
#     --dry-run      show what would happen, change nothing
#
# Tip: rehearse on the dev Mac first with the hardened test host:
#   cmake --preset dev -DMM_TESTHOST_HARDENED=ON && cmake --build --preset dev
#   scripts/m0-resign.sh --app build/dev/testhost/testhost.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

app="$MM_GAME_APP"
debuggable=0
dry_run=0

while [ $# -gt 0 ]; do
    case "$1" in
    --app)
        app="${2:?--app needs a path}"
        shift 2
        ;;
    --debuggable)
        debuggable=1
        shift
        ;;
    --dry-run)
        dry_run=1
        shift
        ;;
    -h | --help)
        sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) mm_die "Unknown option: $1 (try --help)" ;;
    esac
done

mm_require_macos
app="${app%/}"
[ -d "$app/Contents" ] || mm_die "No app found at $app"

plist="$app/Contents/Info.plist"
executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
executable="$app/Contents/MacOS/$executable_name"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null ||
    echo unknown)

mm_info "App:          $app"
mm_note "Executable:   $executable_name"
mm_note "Version:      $version"
mm_note "Architecture: $(lipo -archs "$executable")"

# ---- 1. Safety checks ------------------------------------------------------

if mm_game_is_running; then
    mm_die "The Sims 4 is running. Quit it first."
fi

# The game ships signed by EA. An ad-hoc signature means it was already
# re-signed, and backing it up now would save the modified copy, not the
# original. (The hardened test host is always ad hoc, so this only applies to
# the game.)
current_signature=$(codesign -dv "$app" 2>&1 || true)
if [ "$app" = "$MM_GAME_APP" ] && printf '%s' "$current_signature" | grep -q 'Signature=adhoc'; then
    mm_die "The game is already signed ad hoc, so it has probably been re-signed before." \
        "Run scripts/m0-restore.sh first, so the backup is of the original."
fi

if [ ! -w "$app/Contents/MacOS" ]; then
    mm_die "No write access to $app. Run from an admin account, or with sudo."
fi

executable_hash=$(shasum -a 256 "$executable" | awk '{ print $1 }')
backup_dir="$MM_SUPPORT_DIR/backups/game/${version}_${executable_hash:0:12}"

if [ "$dry_run" -eq 1 ]; then
    mm_info "Dry run: would back up saves, back up the executable to $backup_dir," \
        "and re-sign $app. Nothing changed."
    exit 0
fi

if ! mm_confirm "This re-signs $app. A backup is kept and m0-restore.sh undoes it."; then
    mm_info "Cancelled. Nothing changed."
    exit 0
fi

# ---- 2. Save backup --------------------------------------------------------

if [ "$app" = "$MM_GAME_APP" ]; then
    mm_info "Backing up Sims saves first."
    "$SCRIPT_DIR/backup-sims-saves.sh" || mm_die "Save backup failed. Not touching the game."
fi

# ---- 3. Back up the executable and signature (once per game build) ---------
# Keyed by version and executable hash, so repeated runs never pile up copies.

if [ -d "$backup_dir" ]; then
    mm_info "Backup for this exact game build already exists; reusing it."
else
    mm_info "Backing up the original executable and signature."
    mkdir -p "$backup_dir.partial"
    cp -p "$executable" "$backup_dir.partial/"
    if [ -d "$app/Contents/_CodeSignature" ]; then
        cp -Rp "$app/Contents/_CodeSignature" "$backup_dir.partial/"
    fi
    codesign -dvvv "$app" >"$backup_dir.partial/codesign-before.txt" 2>&1 || true
    codesign -d --entitlements - --xml "$app" >"$backup_dir.partial/entitlements-original.plist" \
        2>/dev/null || true
    printf '%s\n' "$executable_name" >"$backup_dir.partial/executable-name.txt"
    printf '%s\n' "$app" >"$backup_dir.partial/app-path.txt"
    printf '%s\n' "$executable_hash" >"$backup_dir.partial/executable.sha256"
    mv "$backup_dir.partial" "$backup_dir"

    # Executables are large. Keep only the two newest game builds' backups.
    find "$MM_SUPPORT_DIR/backups/game" -mindepth 1 -maxdepth 1 -type d -not -name '*.partial' \
        -exec stat -f '%m %N' {} \; | LC_ALL=C sort -rn | cut -d' ' -f2- | sed -n '3,$p' |
        while IFS= read -r old_backup; do
            mm_note "Removing old game backup $(basename "$old_backup")"
            rm -rf "$old_backup"
        done
fi
mm_note "Backup: $backup_dir"

# ---- 4. Build entitlements and re-sign -------------------------------------

entitlements="$backup_dir/entitlements-metalmix.plist"
if [ -s "$backup_dir/entitlements-original.plist" ]; then
    cp "$backup_dir/entitlements-original.plist" "$entitlements"
else
    cat >"$entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
fi

set_entitlement() {
    /usr/libexec/PlistBuddy -c "Add :$1 bool true" "$entitlements" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Set :$1 true" "$entitlements"
}
set_entitlement com.apple.security.cs.disable-library-validation
if [ "$debuggable" -eq 1 ]; then
    set_entitlement com.apple.security.get-task-allow
fi

mm_info "Re-signing ad hoc with these entitlements:"
plutil -p "$entitlements" | sed 's/^/    /'

if ! codesign --force --sign - --options runtime --entitlements "$entitlements" "$app"; then
    mm_warn "codesign failed. If the message says 'Operation not permitted', allow Terminal under"
    mm_warn "System Settings > Privacy & Security > App Management, then run this again."
    mm_die "Re-signing failed. Run scripts/m0-restore.sh to be safe."
fi

# ---- 5. Verify -------------------------------------------------------------

if codesign --verify --deep --strict --verbose=2 "$app"; then
    mm_info "Signature verifies."
else
    mm_warn "The new signature did not verify. Run scripts/m0-restore.sh."
    exit 1
fi

cat <<EOF

==> Re-signed. Now test M0 (see docs/testing.md):
    1. Open the EA app and launch The Sims 4 from it.
    2. Load a save and play for about 10 minutes.
    3. Note anything odd: EA app warnings, "repair" prompts, crashes.
    4. Quit the game and run scripts/m0-restore.sh to put the original back.
EOF
