# MetalMix

MetalMix is an open-source post-processing injector for the native Metal build of
The Sims 4 on macOS. It loads a small library into the game, runs a chain of
shader effects on each finished frame, and shows an in-game overlay to control
them. Think ReShade, but for Macs.

> **Status: pre-alpha.** Nothing here is ready for players yet. The project is at
> milestone M0 (proving the game still launches after being re-signed). See
> [docs/architecture.md](docs/architecture.md) for the full plan.

## What it will do

- Colour, sharpening, bloom, LUT and (later) depth-based effects on The Sims 4.
- **Beginner mode:** pick a preset, move a few plain-language sliders.
- **Advanced mode:** every parameter, effect order and diagnostics.
- Make your own looks by stacking blocks in the overlay, or by writing a short
  Metal function (a "Mix snippet").
- Load existing ReShade `.fx` shaders and `.ini` presets (planned).

## Safety first

MetalMix is designed so that the game always still works:

- If MetalMix is missing, broken or disabled, the game starts normally.
- Hold **Option** while the game launches to skip MetalMix for that launch.
- A crash guard turns MetalMix off by itself after two failed launches.
- Your saves are backed up before every test session, and the backups are kept
  small (see [docs/testing.md](docs/testing.md)).
- Uninstalling restores the original game files.

## Repository layout

| Folder | What lives there |
| --- | --- |
| `include/metalmix/` | The C API shared by the loader and the core |
| `loader/` | `mmloader.dylib`: tiny, stable library patched into the game |
| `core/` | `mmcore.dylib`: hooks, effect runtime, overlay, control server |
| `testhost/` | A small Metal app that stands in for the game during development |
| `tools/` | `mmctl` (control CLI), `fxc-metal` (planned), installer (planned) |
| `shaders/` | Bundled effects and the shared `metalmix.h` header |
| `presets/` | Bundled presets (added in milestone M4b) |
| `scripts/` | Backups, the M0 re-sign spike, deploy and reporting scripts |
| `tests/` | Unit, translation and golden-image tests, plus recorded fixtures |
| `docs/` | Architecture, setup, testing, user and authoring guides |

## Building (developers)

Requirements: a Mac with Apple Silicon, Xcode (command line tools are enough for
the dylibs), CMake 3.24 or newer, and Ninja (`brew install cmake ninja`).

```sh
cmake --preset dev
cmake --build --preset dev
```

Then follow [docs/dev-setup.md](docs/dev-setup.md) to run the test host with
MetalMix injected.

## License

MetalMix's own code is under the MIT License (see [LICENSE](LICENSE)). Third-party
components keep their own licenses; see [NOTICE.md](NOTICE.md).

MetalMix is a fan project. It is not made by, endorsed by or affiliated with
Electronic Arts or Maxis. The Sims is a trademark of Electronic Arts Inc.
