# Testing

Most testing happens on the dev Mac against the test host. Time on the test Mac
is for confirming, and it is someone's personal computer with their saves on it,
so every session follows the same routine.

## Every test session on the test Mac

1. **Quit the game.** Double-click `start-test-session.command`. It backs up the
   saves and shows a checklist. If the backup fails, do not test.
2. **Check EA auto-update is off** for The Sims 4 (the checklist reminds you).
3. **Test.** Watch over Parsec from the dev Mac if you are not at the test Mac.
4. **Report.** Double-click `mm-report.command`, or pull logs over SSH.

The save backup also runs automatically inside `m0-resign.sh` and
`mm-update.command`, and both stop if it fails.

## Save backups

`scripts/backup-sims-saves.sh` is built so backups never grow to many gigabytes.

| Rule | Default | Change with |
| --- | --- | --- |
| Backs up only `saves/*.save`, `Options.ini`, `GameVersion.txt` | Always | `--with-tray` adds `Tray/` |
| Never backs up `.ver0` to `.ver4` copies, Mods, caches, thumbnails | Always | Not configurable |
| Skips the backup if nothing changed since the last one | On | Not configurable |
| Keeps only the newest backups | 3 | `MM_BACKUP_KEEP=5` |
| Deletes oldest while the total is over a cap (never the newest) | 2048 MB | `MM_BACKUP_MAX_MB=4096` |
| Refuses to run with less free space than the saves plus 1 GB | On | Not configurable |
| Refuses to run while the game is running | On | `--force` |

Backups are compressed and stored in
`~/Library/Application Support/MetalMix/backups/sims-saves/`, outside
`~/Documents` so iCloud never uploads them. Each backup has a `.txt` file next to
it listing the date, game version, sizes and files.

```sh
scripts/backup-sims-saves.sh --list      # what exists and how big
scripts/backup-sims-saves.sh --dry-run   # what would be backed up
scripts/restore-sims-saves.sh --latest   # put the newest backup back
```

Restoring never deletes anything: the current `saves` folder is moved aside to
`saves.before-restore-<date>` first.

Game executable backups (made by `m0-resign.sh`) are kept once per game build
and only for the two newest builds.

## M0: the re-sign spike

Goal: prove the EA app still launches The Sims 4 after it is re-signed ad hoc.
Nothing else is built until this passes.

**Rehearse on the dev Mac first:**

```sh
cmake --preset dev -DMM_TESTHOST_HARDENED=ON && cmake --build --preset dev
scripts/m0-resign.sh --app build/dev/testhost/testhost.app
open build/dev/testhost/testhost.app
```

**Then on the test Mac:**

1. Quit the game. Run `scripts/m0-resign.sh --dry-run` and read what it will do.
2. Run `scripts/m0-resign.sh`. It backs up saves, backs up the executable and
   signature, re-signs, and verifies.
3. Launch the game **from the EA app**. Load a save, play about 10 minutes.
4. Record the result below.
5. Quit, then run `scripts/m0-restore.sh`. If anything still looks wrong, use
   Repair on The Sims 4 in the EA app.

**M0 result** (fill in):

| Question | Answer |
| --- | --- |
| Date, game version | |
| Did `codesign` succeed and verify? | |
| Did the EA app launch the game without warnings or repair prompts? | |
| Did the game load a save and play normally? | |
| Did the EA app change anything after quitting (repair, re-download)? | |
| Did `m0-restore.sh` verify? | |
| Pass or fail | |

If M0 fails, the fallback is a launcher that starts the game executable with
`DYLD_INSERT_LIBRARIES` (see Risks in `architecture.md`).

## Device smoke checklist (every build sent to the test Mac, from M5)

- [ ] `start-test-session.command` backed up saves (or reported no changes)
- [ ] Game launches from the EA app and reaches the main menu
- [ ] `mmctl status` shows the core loaded with the right build commit
- [ ] Overlay opens, closes, and does not leak input to the game
- [ ] A preset loads; toggling effects changes the image
- [ ] Depth view shows the scene (from M7)
- [ ] 30-minute play session: no crash, GPU time within budget after warm-up
- [ ] Kill switch and Option-at-launch both give a vanilla game
- [ ] Uninstall restores the original game and the EA app launches it
