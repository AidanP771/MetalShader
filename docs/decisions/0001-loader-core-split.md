# 0001: Split a tiny loader from a replaceable core

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Code patched into the game's bundle means re-signing the game every time it
changes. MetalMix changes constantly during development and is deployed to the
test Mac over the network.

## Decision

Only `mmloader.dylib` (a few hundred lines, rarely changed) goes into the game
bundle. It loads `mmcore.dylib` from `~/Library/Application Support/MetalMix/`,
which can be replaced freely. They share one small header, `mm_api.h`, with a
version number.

## Consequences

- Deploying a new core is a file copy, not a re-sign.
- The loader must stay tiny and backwards compatible; new features go in the
  core.
- A user-writable folder holds code that runs in the game, which needs the hash
  check in 0003.
