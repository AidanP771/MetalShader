# shaders

| Folder | Contents |
| --- | --- |
| `include/` | `metalmix.h`, shared by every Metal effect and Mix snippet |
| `bundled/` | Effects that ship with MetalMix: `.metal` source plus a `.mmfx.json` manifest |
| `examples/` | Example Mix snippets (`.mix`) used in `docs/authoring.md` |

On the player's Mac these are installed to
`~/Library/Application Support/MetalMix/shaders/`, next to a `user/` folder for
their own effects and snippets. Updates replace `bundled/` and `include/` and
never touch `user/`.

## Formats (drafts until M4b)

- **Native effect:** a `.metal` file with one or more fragment functions, and a
  `.mmfx.json` manifest naming the passes and parameters. See `bundled/invert.*`.
- **Mix snippet:** one `apply` function plus `@param` comments. MetalMix
  generates the rest. See `examples/warm-fade.mix`.
- **ReShade `.fx`:** translated at runtime from M6.

Do not add community shaders here. Licenses vary; see `NOTICE.md`.
