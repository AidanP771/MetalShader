# loader

`mmloader.dylib` is the only MetalMix code patched into the game. The installer
adds a weak load command for it to the game's executable and copies it into
`The Sims 4.app/Contents/Frameworks/`.

## What it does

When the game starts, `mm_loader_init` runs once and, in order:

1. **Kill switch:** stops if `MM_DISABLE=1` is set, a `DISABLED` file exists in
   the MetalMix folder, or Option is held.
2. **Crash guard:** stops if the last two launches never reached healthy frames.
   Otherwise it counts this launch in the `launching` marker file. The core
   deletes that file after 300 healthy frames.
3. **Core integrity (Release builds):** stops unless the core's SHA-256 matches
   `mmcore.sha256` next to the loader. Dev builds skip this and log a warning.
4. **Load:** `dlopen`s the core and calls `mm_core_start`.

Every failure is logged and then simply returns. The game keeps running.

## Entry points

- `mm_loader_init` (constructor, `src/mm_loader.c`).

## Must never

- Crash, abort or throw. There is nothing above it to catch the error.
- Block for long. It runs before the game's `main()`.
- Grow features. New behaviour belongs in the core.

## Environment variables

| Variable | Builds | Effect |
| --- | --- | --- |
| `MM_DISABLE=1` | All | Skip MetalMix for this launch |
| `MM_CORE_PATH=/path/to/mmcore.dylib` | Dev only | Load this core instead of the one in the MetalMix folder |
