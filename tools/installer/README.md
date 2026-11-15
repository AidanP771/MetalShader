# installer (planned, M5)

`MetalMix Installer.app`, a SwiftUI app that does what `scripts/m0-resign.sh`
does by hand, with a friendly interface:

1. Back up the player's saves (`scripts/backup-sims-saves.sh` logic).
2. Find the game, record its version and hash, back up the executable and
   signature.
3. Add the weak load command, copy `mmloader.dylib` into `Contents/Frameworks/`,
   write `mmcore.sha256` there.
4. Re-sign ad hoc with the game's entitlements plus
   `com.apple.security.cs.disable-library-validation`.
5. Install the core, shaders and bundled presets into the MetalMix folder.
6. Offer Uninstall (restore from backup) and Re-patch (after a game update).

Until it exists, use the scripts in `scripts/`.
