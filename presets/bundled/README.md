# Bundled presets

Presets that ship with MetalMix. Added in milestone M4b, built only from Mix
builder blocks so they work in Beginner mode and before depth support exists.

Planned set (names and tuning to be decided with the tester on the test Mac):
natural boost, warm, cool cinematic, soft and dreamy, vivid, film, black and
white, crisp.

Format: `.mmpreset` (JSON) with the ordered effects, every parameter value, and
a thumbnail. Installed read-only; players' own presets go in `presets/user/` on
their Mac.

Bundled LUTs and textures must be made for MetalMix, not copied (see `NOTICE.md`).
