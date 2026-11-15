# 0004: Small, automatic save backups before every test session

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Testing happens on a partner's personal Mac with real saves. A crash while the
game saves can corrupt a save. Naive backups (copying the whole Sims folder each
session) would quickly use many gigabytes, because Mods, caches and the game's
own `.ver` save copies are large.

## Decision

`scripts/backup-sims-saves.sh` runs at the start of every test session and
before anything that changes the game. It backs up only `saves/*.save`,
`Options.ini` and `GameVersion.txt` (Tray optional), skips unchanged saves,
compresses, keeps the newest 3, caps the total at 2 GB, and stores backups
outside `~/Documents` so iCloud does not upload them.

## Consequences

- A normal test day adds one small backup at most.
- Mods are not backed up; MetalMix never touches them.
- Restores never delete: the current saves are moved aside first.
