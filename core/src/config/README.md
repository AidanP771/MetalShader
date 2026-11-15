# config

Reads and writes `config.json` and preset files. Starts in M3.

- `config.json` lives in `~/Library/Application Support/MetalMix/`. See
  `config/config.example.json` at the repo root for every field.
- Unknown fields are kept when saving, so newer and older cores can share one
  file.
- Presets: `.mmpreset` (MetalMix JSON) in `presets/bundled/` (read-only) and
  `presets/user/`. ReShade `.ini` files are converted on import.
- File reads and writes happen on a background queue, never on the render
  thread.
