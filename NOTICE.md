# Third-party notices

MetalMix's own code is MIT licensed. The components below are planned and will
be added as git submodules under `third_party/` when the milestone that needs
them starts. Each keeps its own license, and the full license text of each must
ship with every release.

| Component | Used for | License | Added in |
| --- | --- | --- | --- |
| [Dear ImGui](https://github.com/ocornut/imgui) | In-game overlay | MIT | M4 |
| [ReShade](https://github.com/crosire/reshade) (`reshadefx` compiler source only) | Parsing ReShade `.fx` effects | BSD-3-Clause | M6 |
| [SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross) | SPIR-V to Metal Shading Language | Apache-2.0 | M6 |

Rules:

- Vendor only what is used. From ReShade, that is the effect compiler, not the
  whole project.
- Do not bundle community `.fx` shaders. Their licenses vary and some have none.
  Users install the shaders they want themselves.
- Bundled LUT textures and presets are made for MetalMix, not copied.
- "ReShade" and "GShade" are other projects' names. Do not use them in MetalMix
  branding.
- The Sims is a trademark of Electronic Arts Inc. MetalMix never redistributes
  any EA files.
