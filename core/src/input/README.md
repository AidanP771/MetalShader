# input

Hotkeys and overlay input, through a swizzle of `-[NSApplication sendEvent:]`.
Starts in M4.

- Overlay closed: every event goes straight to the game, except MetalMix hotkeys.
- Overlay open: keyboard and mouse go to ImGui and are not forwarded.
- Mouse positions are converted from window points to drawable pixels using the
  window's backing scale (Retina).
- Hotkeys come from `config.json`. Defaults must be checked against The Sims 4's
  own bindings first, and Mac keyboards often lack a Home key.
