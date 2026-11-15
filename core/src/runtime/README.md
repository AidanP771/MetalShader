# runtime

The effect runtime: turns the active preset into GPU passes and runs them each
frame, inside the present hook. Starts in M2.

## Responsibilities

- Resources: `mm_color` (RGBA16Float copy of the frame), `mm_depth`, named
  render targets, history textures. Recreated when the drawable size or format
  changes.
- Pass chain: techniques and passes with targets, blend state and clears.
  Pipeline states cached by a hash of shader plus state.
- Standard uniforms: timer, frame count, frame time, screen size, mouse, keys,
  random, depth parameters.
- Hot reload: a `DispatchSource` on `shaders/` and `presets/` recompiles only
  the changed effect.
- GPU timing per effect from the command buffer's `GPUStartTime`/`GPUEndTime`.

## Fail-open rules

- Compiles happen on a background queue. A new chain swaps in only when every
  pass compiled.
- A compile error keeps the last good chain (or pass-through) and shows the error
  in the overlay.
- A runtime error or a GPU fault in the command buffer switches to pass-through
  and disables the effect that changed last.
