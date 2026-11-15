# 0002: Load the loader with a weak load command

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

If a normal load command points at a missing library, dyld refuses to start the
app. Players delete things, updates move things, and MetalMix must never be the
reason the game will not open.

## Decision

The installer adds `LC_LOAD_WEAK_DYLIB` for
`@executable_path/../Frameworks/mmloader.dylib`. If the loader is missing, the
game starts without it.

## Consequences

- A missing or removed loader means a vanilla game, never a crash at launch.
- After an EA update replaces the executable, the patch is simply gone and the
  game runs vanilla until the installer re-patches it.
