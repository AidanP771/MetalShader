# Creating effects for MetalMix

> Draft. The formats below are settled during M2 to M4b. CI will compile every
> code example on this page with `xcrun metal`, so keep them complete.

There are four ways to make an effect, from easiest to most control:

| Way | Where | Good for |
| --- | --- | --- |
| Mix builder | In-game overlay | Stacking adjustments with sliders, no code |
| Mix snippet (`.mix`) | Any text editor or the overlay's code editor | A custom look in one short function |
| Native effect (`.metal` + `.mmfx.json`) | Text editor | Multi-pass effects, full control |
| ReShade `.fx` | Text editor | Reusing existing ReShade shaders (from M6) |

## Mix builder

A layer stack, like a photo editor. Each layer is a block (Exposure, Contrast,
Saturation, Vibrance, White balance, Lift/Gamma/Gain, LUT, Sharpen, Bloom,
Vignette, Film grain, Chromatic aberration; Depth of field and Fog once depth
works) with its own sliders, opacity, blend mode and optional mask. "Open as
code" turns the stack into a Mix snippet.

## Mix snippets

One function and some `@param` comments. MetalMix writes the rest.

```metal
// @name   Warm Fade
// @param  float warmth  0.0 1.0 0.3  "Warmth"
// @param  float fade    0.0 1.0 0.2  "Fade"

float4 apply(float2 uv, float4 color, MixContext ctx) {
    color.rgb += float3(0.06, 0.02, -0.04) * warmth;
    color.rgb = mix(color.rgb, float3(0.5), fade * 0.3);
    return color;
}
```

- `@param <type> <name> <min> <max> <default> "<label>"` becomes a slider.
- `MixContext` gives `ctx.sample(uv)`, `ctx.depth(uv)`, `ctx.time` and
  `ctx.resolution`.
- Save the file in `~/Library/Application Support/MetalMix/shaders/user/` and it
  reloads while the game runs. Errors show in the overlay on the right line.

## Native effects

A `.metal` file plus a `.mmfx.json` manifest. See `shaders/bundled/invert.metal`
and `invert.mmfx.json`. Include `metalmix.h` for the shared structs and binding
names.

## ReShade `.fx`

From M6, drop `.fx` files and their textures into `shaders/user/Shaders/` and
`shaders/user/Textures/`. Not every effect translates; the compatibility list
lives here once it exists.
