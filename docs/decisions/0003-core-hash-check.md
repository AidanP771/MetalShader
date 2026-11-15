# 0003: Release loaders only load a core with a matching hash

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

MetalMix turns off library validation for the game, and the core lives in a
user-writable folder (0001). Without a check, any program could drop an
`mmcore.dylib` there and have it run inside the game.

## Decision

The installer writes the SHA-256 of the core it installs to
`Contents/Frameworks/mmcore.sha256` inside the game bundle. Release loaders
refuse any core that does not match. macOS App Management protection (macOS 13
and later) stops other apps from rewriting files inside app bundles without the
user's permission, so both files cannot be swapped quietly. Dev loaders skip the
check and log a warning.

## Consequences

- Updating the core in a Release install goes through the installer, which
  rewrites the hash.
- Dev loaders must never ship; CI release builds set `MM_DEV_BUILD=OFF`.
