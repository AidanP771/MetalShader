# testhost

A small Metal app that behaves enough like The Sims 4 for most MetalMix work to
happen on the dev Mac: a window, an `MTKView` with a `CAMetalLayer`, a depth
buffer, and one render pass per frame ending in `presentDrawable:`.

## Run it with MetalMix injected

```sh
cmake --build --preset dev
scripts/inject-testhost.sh
```

The script sets `DYLD_INSERT_LIBRARIES` to the freshly built loader and
`MM_CORE_PATH` to the freshly built core, then launches the app. Watch the logs
in another terminal:

```sh
log stream --predicate 'subsystem == "io.metalmix"' --level debug
```

## Two variants

| Variant | How to build | Used for |
| --- | --- | --- |
| Plain (default) | `cmake --preset dev` | Day-to-day injection with `DYLD_INSERT_LIBRARIES` |
| Hardened | `cmake --preset dev -DMM_TESTHOST_HARDENED=ON` | Testing the patch and re-sign path, signed like the game |

## Planned additions

These make the test host a better stand-in as later milestones need them:

- A UI layer drawn after the scene without depth (M7, before-UI detection).
- Switchable depth storage: stored, `DontCare`, `memoryless` (M7).
- A resizable window and fullscreen toggle for resize tests (M2).
