# core

`mmcore.dylib` is everything MetalMix does inside the game: Metal hooks, the
effect runtime, depth detection, the overlay, input and the dev control server.
It is loaded by `mmloader.dylib` and entered through `mm_core_start`
(`src/mm_core.mm`).

## Layout

Each folder under `src/` is one subsystem from `docs/architecture.md` and has its
own README.

| Folder | Subsystem | Starts in |
| --- | --- | --- |
| `log/` | `MMLog` macros over `os_log` | Scaffold |
| `hooks/` | Class discovery and swizzles | M1 |
| `runtime/` | Effect chain, render targets, uniforms, hot reload | M2 |
| `ui/` | Dear ImGui overlay, Beginner and Advanced modes | M4 |
| `input/` | `sendEvent:` hook and hotkeys | M4 |
| `control/` | `ctl.sock` server for `mmctl` (Dev builds only) | M4 |
| `config/` | `config.json`, presets | M3 |
| `depth/` | Pass log, depth scoring, force-store | M7 |

## Rules for code in the core

- **Fail open.** On any error, call the original implementation and switch the
  runtime to pass-through.
- **Never block the render thread.** File I/O, shader compiles and anything slow
  go on a background queue.
- **Start cheap.** `mm_core_start` runs before the game's `main()`. Install hooks
  and return; real setup waits for the first presented frame.
- **Health reporting.** Call `MMCoreReportHealthyFrame()` once per successfully
  presented frame. After 300 it clears the loader's crash marker.
