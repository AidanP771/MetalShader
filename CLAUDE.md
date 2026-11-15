# CLAUDE.md

Guidance for Claude Code (and any other contributor) working in this repository.

## What this project is

MetalMix injects a post-processing shader pipeline into the native arm64 Metal
build of The Sims 4 on macOS. The full design is in `docs/architecture.md`. Read
the section for the subsystem you are touching before changing it.

## Machines

- **Dev Mac:** M2, macOS 27. Builds everything. Does not have The Sims 4.
- **Test Mac:** partner's MacBook Air M4, macOS 15.6. Runs the game. It is
  someone's personal computer: never add background services, launch agents or
  anything outside the MetalMix folder and the patched game.

Develop against `testhost/` first. Only confirm on the game.

## Hard rules

1. **Fail open.** Any error in MetalMix must leave the game running vanilla.
   Hooks call the original implementation on every error path.
2. **Never block the render thread.** No file I/O, network, locks held across
   frames, or shader compiles on the thread that calls `presentDrawable:`.
3. **The game process never touches the network or git.** Reporting is done by
   scripts the user runs.
4. **Never hardcode private Metal class names.** Discover them at runtime.
5. **Back up saves before anything that changes the game.** Scripts that modify
   the game call `scripts/backup-sims-saves.sh` first and stop if it fails.
6. **Docs change with code.** A change to behaviour updates the matching page in
   `docs/` in the same commit or pull request.

## Build

```sh
cmake --preset dev && cmake --build --preset dev        # arm64, dev features on
cmake --preset release && cmake --build --preset release # universal, dev features off
```

Deployment target is macOS 15.0 (the test Mac). Do not use APIs newer than
macOS 15 without an availability check.

## Code style

- C and Objective-C++ (C++20). `.clang-format` is the source of truth; run
  `clang-format -i` on changed files (version 23.1.5, pinned to match CI).
- Every file starts with a comment: purpose, threading rules, who calls it.
- Every swizzle gets a comment saying which Metal behaviour it relies on and why.
- Spell names out (`DepthCandidateScorer`, not `dcs`). No magic numbers: use
  named constants with units in the name (`kCrashGuardHealthyFrames`).
- Small functions, early returns. Log errors as a plain sentence plus the values
  needed to act on them, through `MMLog` (core) or `os_log` (loader).
- Prefix: `mm_` for C symbols, `MM` for Objective-C classes and C++ types,
  `MM_` for macros.

## Writing style for docs and comments

Plain language, short sentences, every command copy-pasteable. Avoid em dashes.
Write for a Sims player in user docs and for a new contributor in developer docs.

## Where things go

| Change | Files |
| --- | --- |
| Loader behaviour | `loader/src/mm_loader.c`, `include/metalmix/mm_api.h`, `docs/architecture.md` (Loading) |
| A new hook | `core/src/hooks/`, its README, `docs/architecture.md` (Metal hooking layer) |
| A new `mmctl` command | `core/src/control/`, `tools/mmctl/README.md`, `docs/dev-setup.md` |
| A test-Mac script | `scripts/`, `docs/testing.md` |
| A design decision | a new file in `docs/decisions/` |
