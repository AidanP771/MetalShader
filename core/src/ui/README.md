# ui

The in-game overlay, built with Dear ImGui's Metal backend and drawn as the last
pass after all effects. Starts in M4; Beginner and Advanced modes in M4b.

## Panels

- Mode switch (Beginner or Advanced) and the effect list.
- Mix builder: layer stack with sliders, opacity, blend mode and masks.
- Code editor for Mix snippets, with errors shown on the offending line.
- Presets: gallery, load, save, save as, ReShade `.ini` import.
- Depth (Advanced): candidates, debug view, reversed-Z, far plane.
- Stats (Advanced): frame time, GPU time per effect, compile errors.
- Log: recent log lines.

Beginner mode hides depth details and diagnostics, and shows plain-language
slider names. Switching modes never changes the image.
