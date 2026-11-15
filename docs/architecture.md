# MetalMix: Metal Post-Processing Injector for The Sims 4 on macOS

Spec v0.1, Nov 14, 2026. The live copy of this spec is the MetalMix spec doc; keep this file in sync with it.

## Overview

MetalMix is an open-source post-processing injector for the native Metal build of The Sims 4 on macOS. A small dylib loads into the game, hooks frame presentation, runs a chain of shader effects on the final image, and draws an in-game overlay to control them. It aims to fill the gap ReShade and GShade fill on Windows, and to run the presets Sims players already use.

**Goals (v1)**

- Real-time colour, sharpening, bloom and LUT effects on the game's final frame, with a Beginner mode for players and an Advanced mode for shader authors.
- Load existing ReShade `.fx` shaders and `.ini` presets, translated to Metal at runtime.
- Depth-aware effects (DOF, AO, fog) once the scene depth buffer can be found reliably.
- In-game overlay for tuning effects, creating shaders from building blocks or from code, and saving presets. Ships with a set of bundled presets.
- Safe, reversible install: the game must still launch normally if MetalMix is missing, broken or disabled.
- Developed on one Mac and tested remotely on another, with no Sims install on the dev machine.

**Non-goals (v1)**

- Other games. The code stays generic where it costs nothing, but only Sims 4 is supported and tested.
- The Windows build running under CrossOver or Whisky (normal ReShade already covers that).
- Gameplay, lighting or asset mods. Those belong to the Sims script and package modding scene.
- Shipping game files or anything EA owns.

## Machines and roles

All code is written and built on the dev Mac; the test Mac only runs the game and receives builds. Because the test Mac is a partner's everyday computer, every design choice that touches it favours reversibility and staying out of the way.

|  | Dev Mac (Aidan) | Test Mac (partner) |
| --- | --- | --- |
| Role | Write, build, unit and shader tests, test host app | Run The Sims 4 with MetalMix loaded |
| Has The Sims 4 | No | Yes |
| Installed tooling | Xcode, CMake, Ninja, Tailscale | Tailscale, Xcode Command Line Tools (for lldb, optional) |
| Receives | Recorded pass logs, GPU captures, crash reports | Core dylib, shaders, presets, config |
| Access | Local | SSH and Screen Sharing over Tailscale |
| Hardware | M2 | MacBook Air M4 (fanless); The Sims 4 arm64 build from the EA app |

**Rules for the test Mac**

- Everything MetalMix adds lives in one folder plus one patched app; an uninstall script restores the original binary from backup.
- Nothing runs unless the game is running. No daemons, launch agents or background services.
- A kill switch the partner can use without asking (see Loading).
- Testing sessions are scheduled with the partner, since the game window shows on their screen.

**Save backups, every test session.** Every test session starts with `scripts/start-test-session.command`, which runs `scripts/backup-sims-saves.sh` and reminds the partner to pause EA auto-updates. `m0-resign.sh` and `mm-update.command` also run the backup first and stop if it fails. A crash while the game is saving can corrupt a save, which would cost the partner far more than any MetalMix bug.

The backup is built to stay small:

- Only `saves/*.save` plus `Options.ini` and `GameVersion.txt`. Not the game's own `.ver0` to `.ver4` save copies, Mods, caches or thumbnails. Tray is opt-in with `--with-tray`.
- Skipped when nothing changed since the last backup (fingerprint of file names, sizes and times).
- Compressed, keeps the newest 3, and prunes oldest-first above a 2 GB total. All three limits are settings.
- Refuses to run while the game is running, so a half-written save is never captured.
- Stored in `~/Library/Application Support/MetalMix/backups/sims-saves/`, outside `~/Documents`, so iCloud never uploads it. Uninstall keeps backups unless asked to remove them.

**Hardware.** Both Macs are Apple Silicon (dev M2, test MacBook Air M4) and the game runs as the native arm64 build from the EA app, so Dev builds can be arm64 only. The M4 has a newer GPU generation than the M2, so the test host is still run on the test Mac at each milestone to tell "MetalMix bug" from "GPU difference". The Air is fanless and throttles in long sessions, which matters for performance numbers (see Effect runtime).

## Architecture overview

Six components, split so that the only thing ever patched into the game is a tiny loader. Everything that changes often (the core, shaders, presets) lives in one folder the dev Mac can overwrite over the network.

```
Test Mac (partner, MacBook Air M4)
+--------------------------------------------------------------+
|  The Sims 4 process                                          |
|  +--------------------------------+      +----------------+  |
|  | The Sims 4 (Metal renderer)    | <--- | Installer.app  |  |
|  +--------------------------------+ patches +-------------+  |
|          | loads at launch                                   |
|  +--------------------------------+                          |
|  | mmloader.dylib                 |                          |
|  | weak load, kill switch, guard  |                          |
|  +--------------------------------+                          |
|          | dlopen                        +----------------+  |
|  +--------------------------------+ reads| MetalMix folder|  |
|  | mmcore.dylib                   | <--- | core, shaders, |  |
|  | hooks, runtime, depth, mmfx,   |      | presets, config|  |
|  | overlay, ctl.sock (dev)        | <-+  +----------------+  |
|  +--------------------------------+   |         ^            |
+---------------------------------------|---------|------------+
                          mmctl over SSH|         | deploy
Dev Mac (Aidan, M2)                     |         |
+---------------------------------------|---------|------------+
|  Build and tests   testhost.app   mmctl and scripts          |
+--------------------------------------------------------------+
```

The partner's Mac receives files into one folder plus a one-time patch. The dev Mac drives it over Tailscale with rsync and `mmctl`, and pulls logs, pass logs and GPU captures back the same way.

| Component | Language | Changes how often |
| --- | --- | --- |
| `mmloader.dylib` | C / Objective-C | Rarely; changing it means re-patching |
| `mmcore.dylib` | Objective-C++ | Every build |
| `mmfx` (static lib inside core, also used by `fxc-metal`) | C++ | When translation improves |
| `mmctl` | C++ or Swift | Occasionally |
| Installer.app | SwiftUI | Occasionally |
| testhost.app | Objective-C++ or Swift | When it needs to mimic a new game behaviour |

## Loading

MetalMix splits loading into a tiny, stable loader that is patched into the game once, and a core that can be replaced freely. This keeps re-signing the game rare and makes the core easy to update over the network.

**Loader (`mmloader.dylib`)**

- Copied into the game bundle at `Contents/Frameworks/mmloader.dylib`.
- Referenced from the game executable with a `LC_LOAD_WEAK_DYLIB` command. Weak means that if the loader is missing, the game launches vanilla instead of crashing.
- Under 200 lines. It does only five things: check the kill switch, check the crash guard, verify the core's hash, `dlopen` the core from Application Support, and call `mm_core_start(MM_API_VERSION)`.
- If any step fails it logs and returns, leaving the game untouched.

**Core (`mmcore.dylib`)**

- Lives at `~/Library/Application Support/MetalMix/core/mmcore.dylib`, outside the bundle, so updating it never touches the game's signature.
- Ad-hoc signed (Apple Silicon refuses unsigned code). Built arm64 for development; Release builds are universal so Intel Macs running the x86\_64 game also work.
- Its constructor does almost nothing; real setup is deferred to the first presented frame.

**Patching and re-signing (done by the installer)**

1. Detect the game binary and its architectures with `lipo -archs`. Record version, hash and current entitlements (`codesign -d --entitlements :-`).
2. Back up the original executable and its `_CodeSignature` to `backups/<game version>/`.
3. Add the weak load command for every architecture slice, and copy the loader into `Frameworks/`.
4. Re-sign ad hoc, keeping the game's own entitlements and adding `com.apple.security.cs.disable-library-validation`. Dev builds also add `com.apple.security.get-task-allow` (for lldb) and the `MetalCaptureEnabled` Info.plist key (for GPU captures).
5. Verify with `codesign --verify` and a test launch.

**Kill switch and crash guard**

- The loader skips the core if any of these is true: a `DISABLED` file exists in the MetalMix folder, `MM_DISABLE=1` is set, or Option is held while the game launches (read with `CGEventSourceFlagsState`).
- Crash guard: the loader writes a `launching` marker and the core clears it after 300 healthy frames. If the marker is still there on two launches in a row, the loader disables itself and logs why.

**Core integrity check.** Library validation is off and the core lives in a user-writable folder, so any program that writes an `mmcore.dylib` there would get loaded into the game. To prevent this, the installer writes the SHA-256 of the core it installs to `Contents/Frameworks/mmcore.sha256` inside the game bundle, and the Release loader refuses any core that does not match. macOS App Management protection (macOS 13 and later) stops other apps from modifying app bundles without the user's permission, so an attacker cannot simply rewrite both files. Dev builds of the loader skip the check, log a warning, and are never shipped.

**Game updates.** An EA update replaces the executable and removes the patch. Thanks to the weak load and the outside-bundle core, the result is simply a vanilla game. The installer detects the hash change and offers to re-patch.

## Metal hooking layer

The hooking layer swizzles a handful of Objective-C methods on Metal's concrete classes, discovered at runtime, so MetalMix can see every render pass and insert its own work just before each frame is presented. Written in Objective-C++ using `method_setImplementation`, with the original IMP stored for each hook.

**Class discovery.** `MTLCommandBuffer` and `MTLRenderCommandEncoder` are protocols; the real classes are private and differ per GPU family and macOS version. On first frame the core creates a throwaway device, queue, command buffer and render encoder, reads each object's class with `object_getClass`, and hooks those. Debug and capture wrapper classes (present when validation or capture is on) are hooked the same way. Class names are never hardcoded.

| Hook | Purpose |
| --- | --- |
| `-[CAMetalLayer nextDrawable]` | Track the layer, drawable size and pixel format |
| `-[CAMetalLayer setFramebufferOnly:]` | Force `NO` so the drawable texture can be sampled |
| `presentDrawable:` and its `atTime:` / `afterMinimumDuration:` variants | Frame boundary: encode MetalMix passes, then call the original |
| `renderCommandEncoderWithDescriptor:` | Record each pass: attachments, sizes, load and store actions |
| `-[MTLRenderCommandEncoder endEncoding]` | Pass end; copy depth here if the game reuses the texture later |
| `newTextureWithDescriptor:` on the device class | Track depth textures; optionally change memoryless storage to private (see Depth) |
| `-[NSApplication sendEvent:]` | Hotkeys and overlay input |

**Present flow.** Inside the `presentDrawable:` hook, the command buffer is not yet committed, so MetalMix encodes its own render passes into the same buffer, writes the result back to the drawable, draws the overlay, then calls the original present. No extra command buffer or sync is needed.

**Safety rules**

- A thread-local re-entrancy flag stops MetalMix's own Metal calls from triggering its hooks.
- Every hook body is wrapped in `@try` and C++ `try`. On any error the hook calls the original and marks the runtime as failed (pass-through).
- Hooks stay installed for the process lifetime. The core is never unloaded at runtime; a new core means relaunching the game.

## Effect runtime

The runtime turns the active preset into an ordered list of GPU passes and runs them each frame, falling back to an untouched frame whenever anything goes wrong.

**Resources**

- `mm_color`: a copy of the game's frame, in RGBA16Float to avoid banding between passes.
- `mm_depth`: the selected depth texture, or a 1x1 placeholder until one is found.
- Named render targets declared by effects, plus persistent history textures for temporal effects.
- Everything is recreated when the drawable size or pixel format changes.

**Passes.** Each effect contributes techniques; each technique is a list of passes with targets, blend state and clear flags. Pipeline states are built once and cached by a hash of shader plus state. The last pass converts back to the drawable's format, handling both sRGB 8-bit and 10-bit or EDR formats.

**Standard uniforms** (ReShade-compatible names where they exist): timer, frame count, frame time, screen size, mouse position and buttons, key state, random value, depth near/far and reversed-Z flag.

**Fail-open behaviour**

- Shaders compile on a background queue. A new effect chain swaps in only when every pass compiled.
- A compile error keeps the previous chain, or pass-through if there was none, and shows the error in the overlay.
- A runtime error (bad texture, exception in a hook) switches the whole runtime to pass-through for the rest of the session.

**Performance.** GPU time per frame is measured from `GPUStartTime` and `GPUEndTime` on the command buffer and shown per effect in the overlay. Target: under 1 ms added for a basic colour plus sharpen preset at 1080p on the test Mac. The MacBook Air M4 is fanless, so timings are taken after a 10-minute warm-up and compared against an effects-off run in the same session.

**Hot reload.** A `DispatchSource` watches the shader and preset folders. Saving a file recompiles only the affected effect, so shader work never needs a game restart.

## Depth buffer detection

Depth is found by recording every render pass for a few frames, scoring the depth attachments, and letting the user override the pick. This is the riskiest subsystem, so it is designed to be developed mostly offline from recorded data.

**Pass log.** For each pass the hooks record: depth and colour attachment textures, sizes, pixel formats, load and store actions, and draw call count (counted via the encoder's draw methods). `mmctl dump-passes` writes a few frames of this as JSON.

**Scoring a candidate**

- Size matches the drawable, or the drawable times the game's resolution scale.
- Cleared once per frame and used by the pass with the most draw calls.
- Stored at pass end (`MTLStoreActionStore`). A depth buffer that is not stored cannot be read later.
- Same texture chosen last frame (stability bonus).

**The Apple Silicon problem.** Tile-based GPUs let games skip storing depth (`DontCare` store action, or `memoryless` storage), which is good for performance and bad for us. If the best candidate is not stored, MetalMix can force it: change `memoryless` to `private` in the `newTextureWithDescriptor:` hook and set the store action to `Store` on that pass. This costs memory bandwidth, so it is opt-in per preset and its cost is shown in the overlay.

**Manual picker.** The overlay lists candidates with size, format, draw count and a live thumbnail. The user's choice is saved per resolution. A "display depth" debug view plus reversed-Z and far-plane controls match what ReShade users already know.

**Effects under the UI.** On Windows, ReShade's effects also tint the game UI. Sims 4 is UI-heavy, so a stretch goal is a "before UI" mode: detect the first pass after the main scene that draws without depth (the UI), and run the effect chain there instead of at present. The pass log is what makes this detectable.

## Overlay UI and input

The overlay is Dear ImGui with its Metal backend, drawn as the very last pass into the drawable, after all effects.

**Panels**

- Mode switch and effects: Beginner or Advanced (see Shader authoring); enable, disable and reorder effects; parameters generated from each effect's annotations.
- Presets: load, save, save as, import a ReShade `.ini`.
- Depth: candidate picker, depth debug view, reversed-Z and far-plane settings.
- Stats: frame time, GPU time per effect, compile errors.
- Log: the last few hundred log lines.

**Input.** The `sendEvent:` hook passes every event straight to the game unless it is a MetalMix hotkey or the overlay is open. While open, keyboard and mouse events go to ImGui and are not forwarded. Mouse positions are converted from window points to drawable pixels using the window's backing scale (Retina).

**Hotkeys** (all configurable in `config.json`)

- Toggle overlay, toggle all effects, take screenshot.
- Defaults are still to be chosen: Mac keyboards often have no Home key, and Sims 4 binds a lot of keys, so defaults must be checked against the game's bindings first.

**Screenshots** are written from the post-effect frame as PNG to `~/Pictures/MetalMix/`, without the overlay.

## Shader frontend

MetalMix accepts two effect formats: native Metal effects (built first, simplest path) and ReShade `.fx` effects translated to Metal at runtime (the main feature for the community).

**Native effects (`.metal` + `.mmfx.json`).** Plain MSL fragment functions, plus a small JSON manifest listing passes, render targets and parameters with UI hints. Used for MetalMix's own bundled effects and for testing the runtime before the translator exists.

**ReShade `.fx` translation pipeline**

1. Preprocess with ReShade's preprocessor, defining the macros effects expect (`__RESHADE__`, `BUFFER_WIDTH`, `BUFFER_HEIGHT`, `RESHADE_DEPTH_INPUT_IS_REVERSED` and similar).
2. Parse and generate SPIR-V with `reshadefx`, ReShade's effect compiler (BSD-3), pinned as a submodule.
3. Convert SPIR-V to MSL with SPIRV-Cross, using its reflection to map textures, samplers and the uniform block to Metal binding indices.
4. Compile MSL with `newLibraryWithSource:` on a background queue; build pipeline states.
5. Map `.fx` annotations (`ui_type`, `ui_min`, `ui_max`, `ui_label`, `ui_items`) to ImGui widgets.

**Caching.** Translated MSL is cached in `~/Library/Caches/MetalMix/` by a hash of the source, macros and compiler version. A later version can add `MTLBinaryArchive` to skip MSL compile too.

**Presets.** ReShade `.ini` presets are parsed for `Techniques=`, `TechniqueSorting=` and per-effect parameter sections, so a player can drop in a preset and its shaders unchanged.

**Compatibility target.** The standard community shader collections first (the official reshade-shaders repo and SweetFX). The translation pass rate across those repos is tracked in CI, and effects that cannot translate are listed in the docs.

## Shader authoring: modes, presets and creation

MetalMix has one effect engine and two ways to use it: Beginner mode for players who want a look without touching code, and Advanced mode for people who write or tune shaders. Shaders can be made by stacking blocks in the overlay or by writing code, and both save as plain files people can edit and share.

|  | Beginner mode | Advanced mode |
| --- | --- | --- |
| Starting point | A gallery of bundled and saved presets | Any preset, Mix file, snippet, `.metal` or `.fx` effect |
| Controls | A few plain-language sliders per block, plus one master Intensity slider | Every parameter, effect order, blend modes, render targets |
| Creating shaders | Mix builder (blocks) | Mix builder plus code editor |
| Depth | One on/off toggle per block once depth is found | Candidate picker, reversed-Z, far plane, force-store |
| Diagnostics | Hidden | GPU time per effect, compile errors, pass log |

The mode is stored in `config.json`. Switching modes never changes the image, only how much of it you can control.

**Creating through the interface: the Mix builder.** A layer stack, like a photo editor. Each layer is a building block with its own sliders, opacity, blend mode and an optional mask (depth range, brightness range or vignette).

- v1 blocks: Exposure, Contrast, Saturation, Vibrance, White balance, Lift/Gamma/Gain, LUT, Sharpen, Bloom, Vignette, Film grain, Chromatic aberration. Depth of field and Fog unlock once depth works.
- A draggable before/after split line shows the effect against the untouched frame.
- The stack saves as a `.mmix` file (readable JSON listing the layers and their values).
- Simple blocks are fused into one generated shader, so a six-layer stack of colour blocks costs about one pass. Blocks that need several passes (bloom, DOF) keep their own.
- "Open as code" turns a stack into a Mix snippet, so a look made with sliders can be continued in text.

**Creating with text: Mix snippets.** A snippet is a single Metal function plus `@param` comments. MetalMix wraps it in a full fragment shader, turns each `@param` into a uniform and a slider, and hot reloads it on save.

```
// @name   Warm Fade
// @param  float warmth  0.0 1.0 0.3  "Warmth"
// @param  float fade    0.0 1.0 0.2  "Fade"
float4 apply(float2 uv, float4 color, MixContext ctx) {
    color.rgb += float3(0.06, 0.02, -0.04) * warmth;
    color.rgb  = mix(color.rgb, float3(0.5), fade * 0.3);
    return color;
}
```

- `MixContext` gives `ctx.sample(uv)`, `ctx.depth(uv)`, `ctx.time` and `ctx.resolution`, so most effects never need to know about passes or bindings.
- Snippets can be edited in the overlay's built-in code editor (Metal syntax highlighting, errors shown on the offending line) or in any external editor; files in `shaders/user/` hot reload.
- Authors who need full control still write complete `.metal` effects or ReShade `.fx`.

**Presets.**

- Format: `.mmpreset`, readable JSON holding the ordered effects, every parameter value and a thumbnail. ReShade `.ini` presets are converted to this on import.
- MetalMix ships about eight bundled presets for common Sims looks (natural boost, warm, cool cinematic, soft and dreamy, vivid, film, black and white, crisp). Names and tuning are done with the partner on the test Mac.
- Bundled presets are built only from Mix blocks, so they work in Beginner mode and before depth support exists. They live in `presets/bundled/` and are read-only; Save As writes to `presets/user/`.
- Stretch: export a preset with the user shaders it needs as one shareable file.

**User code safety.** Every user shader goes through the fail-open compile path, so a broken snippet shows its error and the last good chain keeps running. If a user shader faults or times out the GPU, MetalMix sees the error status on the command buffer and disables the effect that changed last.

## Remote development workflow

The dev Mac drives the test Mac over Tailscale: builds go over with rsync, the running game is controlled through a socket, and logs, pass logs, captures and crash reports come back over SSH.

**Connection setup (once)**

- Tailscale on both Macs, in the same tailnet. Tailscale only provides the private network; SSH and Screen Sharing run over it.
- On the test Mac, enable Remote Login and Screen Sharing in System Settings > General > Sharing, limited to the account that plays the game.
- SSH key auth from the dev Mac, with a `test-mac` host alias in `~/.ssh/config` pointing at the test Mac's Tailscale name.
- The game must run in the logged-in user's GUI session, so it is launched either by the partner or via `ssh test-mac open -a "The Sims 4"` as that user.

**Watching the game: Parsec first, Screen Sharing as backup**

macOS Screen Sharing is how you see what MetalMix is doing on the partner's screen. Tailscale makes the test Mac reachable from anywhere by its tailnet name, as if both Macs were on one LAN; if they are on the same home network, Tailscale uses the direct local path.

1. On the dev Mac, open the Screen Sharing app and connect to the test Mac's Tailscale name (MagicDNS) or its `100.x.y.z` address.
2. Choose a type. **Standard** mirrors the partner's real screen, so you can both watch the same game, and you can switch to observe-only so you don't move their mouse. **High Performance** gives 30 or 60 fps, better colour and stereo audio, but needs both Macs on Apple Silicon and macOS 14 or later, UDP ports 5900 to 5902 reachable (Tailscale carries them), and a fast connection. It uses a virtual display and nobody else can use the Mac during the session, so use it only when you are testing alone.
3. Sign in with the test account's credentials.

Parsec is already set up between the two Macs, so it is the default viewer. It makes its own peer-to-peer connection and does not need Tailscale; if it ever fails to connect through a strict NAT, connect it over Tailscale instead. Screen Sharing is the backup: Standard when the partner is playing and you are watching, High Performance for solo sessions. Tailscale is still required for everything that is not video: SSH, rsync deploys, mmctl, live logs and crash reports. It keeps the test Mac's SSH port off the public internet with no router changes.

Screenshots for judging effects are better taken with `mmctl screenshot` than by eye over the stream, since streaming compression changes the image.

**The inner loop**

1. `make deploy`: build arm64, then rsync `mmcore.dylib`, shaders and presets to the test Mac's MetalMix folder.
2. Relaunch the game if the core changed. Shader or preset changes hot reload with no relaunch.
3. Drive and inspect with `mmctl` over SSH, and watch the result in Screen Sharing.
4. Pull back anything worth keeping: pass logs, captures, screenshots, crash reports.

**Control channel (dev builds only).** The core listens on a Unix socket, `ctl.sock`, in the MetalMix folder (permissions 0600). `mmctl` talks to it, run as `ssh test-mac mmctl <cmd>`. Release builds compile the server out.

| `mmctl` command | Does |
| --- | --- |
| `status` | Core version, GPU, drawable size, active preset, failures |
| `reload [effect]` | Recompile one or all effects |
| `enable` / `disable <effect>` | Toggle an effect |
| `set <effect>.<param> <value>` | Change a parameter |
| `dump-passes [frames]` | Write the pass log as JSON for offline depth work |
| `depth list` / `depth pick <id>` | Inspect and choose depth candidates |
| `capture` | Save a `.gputrace` via `MTLCaptureManager` |
| `screenshot` | Save a post-effect PNG |
| `log-level <level>` | Change logging verbosity |

**Logs.** `os_log` under one subsystem, mirrored to a rolling file in `~/Library/Logs/MetalMix/`. Live view from the dev Mac: `ssh test-mac log stream --predicate 'subsystem == "<subsystem>"' --level debug`.

**GPU captures.** Enabled by the `MetalCaptureEnabled` key the dev patch adds. Captures are copied back and opened in Xcode on the dev Mac. A capture taken on the M4 may not replay on the M2's older GPU. Check this early with the test host; if it fails, replay on the M4 by installing Xcode there for capture sessions.

**Crash reports.** `scripts/pull-crashes.sh` copies `.ips` files from `~/Library/Logs/DiagnosticReports/` on the test Mac. Every build stamps a build ID and keeps its dSYM on the dev Mac for symbolication.

**Debugger (optional).** With `get-task-allow` in the dev signature and Command Line Tools on the test Mac, lldb can attach over SSH. Use it only when logs and captures are not enough.

**Async testing through git.** For sessions where you are not online together, the partner can update and report with two double-clickable scripts, and SSH is kept for live work.

|  | How | Why this way |
| --- | --- | --- |
| Builds | GitHub Actions builds every push to `dev` and publishes it as a rolling `dev-latest` pre-release. `mm-update.command` on the test Mac downloads it and installs it into the MetalMix folder. | The test Mac never needs Xcode or CMake, and compiled binaries stay out of git history. Files fetched by script are not quarantined by Gatekeeper, unlike browser downloads. |
| Reports | `mm-report.command` copies the session's logs, pass logs, screenshots and crash reports into a timestamped folder in a private `metalmix-testbench` repo, then commits and pushes. You `git pull` on the dev Mac. | Logs can contain usernames and file paths, so they never go in the public MetalMix repo. A deploy key scoped to the testbench repo means the test Mac cannot push anywhere else. |
| Live sessions | SSH over Tailscale, as above. | Hot reload, `mmctl` and live logs need a seconds-long loop; git round trips take minutes. |

The game process never touches git or the network: reporting is always a script the partner runs, and nothing syncs in the background.

## On-disk layout and configuration

MetalMix touches exactly two places in the game bundle; everything else lives in the user's Library folders, so uninstalling is a binary restore plus deleting one folder.

```
/Applications/The Sims 4.app/Contents/       (path to confirm on test Mac)
  MacOS/<game executable>                   patched: weak load of mmloader
  Frameworks/mmloader.dylib                  added

~/Library/Application Support/MetalMix/
  core/mmcore.dylib
  shaders/Shaders/  shaders/Textures/        plus shaders/user/ for snippets
  presets/bundled/  presets/user/
  config.json                                hotkeys, active preset, depth picks, budgets
  DISABLED                                   kill switch (presence = off)
  launching                                  crash-guard marker
  ctl.sock                                   dev builds only
  backups/<game version>/                    original executable, signature, hashes

~/Library/Caches/MetalMix/                 translated MSL, pipeline cache
~/Library/Logs/MetalMix/                   rolling text logs
~/Pictures/MetalMix/                       screenshots
```

**`config.json` fields (v1):** `hotkeys`, `activePreset`, `effectsEnabled`, `depth` (picks per resolution, reversed-Z, far plane, force-store), `perfBudgetMs`, `logLevel`. Unknown fields are kept on save so newer and older cores can share one file.

## Testing strategy

Most testing happens on the dev Mac against a stand-in app, so time on the partner's Mac is spent confirming, not debugging. Two ideas make this work: a test host that mimics the game's signing and rendering, and pass logs recorded from the real game and replayed offline.

| Level | Runs on | What it covers |
| --- | --- | --- |
| Unit | Dev Mac, CI | Config and `.ini` parsing, depth scoring against recorded pass logs, Mach-O patcher on fixture binaries |
| Shader translation | Dev Mac, CI | Every `.fx` in the target shader repos through `fxc-metal`, then `xcrun metal -c`; pass rate tracked per build |
| Golden images | Dev Mac (needs a GPU) | Each bundled effect run headless on reference images, compared within a tolerance |
| Test host integration | Dev Mac, and test Mac when GPUs differ | Inject into `testhost.app`; scripted `mmctl` runs: toggle, reload, resize, fullscreen, broken shader falls back to pass-through |
| Patcher | Dev Mac | Patch and re-sign `testhost.app`, which is itself signed with the hardened runtime and library validation like the game |
| Device smoke test | Test Mac | Checklist per build (below) |

**Test host app.** A small Metal app with a 3D scene, a real depth buffer, a UI layer drawn after the scene, and a resizable window. Its depth setup is switchable (stored, `DontCare`, memoryless) so the depth heuristics and force-store path can be tested without the game.

**Pass logs as fixtures.** Pass logs from `mmctl dump-passes` on the test Mac are committed to `tests/fixtures/passlogs/`. Depth and before-UI detection are developed against these on the dev Mac, then confirmed in-game.

**Device smoke checklist (test Mac, every build sent)**

- [ ] Game launches from the EA app and reaches the main menu
- [ ] `mmctl status` shows the core loaded with the right build ID
- [ ] Overlay opens, closes, and does not leak input to the game
- [ ] A preset loads; toggling effects changes the image
- [ ] Depth view shows the scene (from the depth milestone on)
- [ ] 30-minute play session: no crash, GPU time within budget
- [ ] Kill switch and Option-at-launch both give a vanilla game
- [ ] Uninstall restores the original binary and the EA app launches it

## Repo layout and build

One repo, built with CMake and Ninja on the dev Mac and in CI. The core is Objective-C++ (C++20); the installer is SwiftUI.

```
metalmix/
  CMakeLists.txt
  loader/                 mmloader.dylib (tiny, stable)
  core/
    hooks/                class discovery, swizzles, re-entrancy guard
    runtime/              pass graph, render targets, uniforms, hot reload
    depth/                pass log, scoring, force-store
    ui/                   ImGui overlay panels
    input/                sendEvent hook, hotkeys
    control/              ctl.sock server (dev builds only)
    config/               config.json, presets
  fx/
    frontend/             reshadefx preprocess + SPIR-V
    backend/              SPIRV-Cross to MSL, reflection, annotations
  shaders/                bundled native effects (.metal + .mmfx.json)
  testhost/               Metal stand-in app (hardened runtime)
  tools/
    mmctl/                control CLI
    fxc-metal/            offline .fx to .metal translator for CI
    installer/            SwiftUI patch / re-sign / backup / restore app
  scripts/                deploy.sh, resign.sh, pull-crashes.sh, pull-passlogs.sh
  tests/
    unit/  translation/  golden/  fixtures/passlogs/
  third_party/            submodules: reshade (reshadefx), SPIRV-Cross, imgui
  docs/
  .github/workflows/
```

**Build settings**

- `CMAKE_OSX_ARCHITECTURES="arm64;x86_64"` for Release builds only. Dev builds are arm64 only, since both Macs and the game are arm64.
- Two configurations: `Dev` (control socket, verbose logging, capture and debug entitlements) and `Release` (none of those).
- Every build stamps a build ID into the core and archives its dSYM.
- Minimum macOS 15. The dev Mac runs macOS 27 and the test Mac runs 15.6, so the deployment target is pinned to 15.0 and shaders target a Metal Shading Language version that macOS 15 supports.

**CI (GitHub Actions, macOS runner).** Build both configurations, run unit and translation tests, publish the translation pass rate, upload dSYMs. Golden-image tests run locally if the hosted runner has no usable Metal device.

## Code and documentation standards

Clear, human-readable code and docs are release requirements, not cleanup. A contributor should be able to follow any subsystem without asking, and a Sims player should be able to install, use and remove MetalMix from the docs alone.

**Code**

- One subsystem per folder, matching this spec's sections. Each folder has a short `README.md`: what it does, its entry points, and what it must never do (for example, hooks never block the render thread).
- Every file opens with a comment stating its purpose, its threading rules and who calls it.
- Each swizzle carries a comment explaining which Metal behaviour it relies on and why, since hook code is the least obvious code in the project.
- Names are spelled out (`DepthCandidateScorer`, not `dcs`). No magic numbers: named constants with units, such as `kCrashGuardHealthyFrames = 300`.
- Small functions with early returns. Every logged error is a plain-English sentence plus the values needed to act on it.
- The loader/core C API (`mm_core_start` and friends) is documented in its header.
- `clang-format`, `clang-tidy` and `swift-format` configs live in the repo and run in CI.
- Pull requests use a template: what changed, why, and how it was tested on which Mac.

**Documentation**

| Doc | Audience | Contents |
| --- | --- | --- |
| `README.md` | Everyone | What MetalMix is, screenshots, install in a few steps, safety notes, uninstall |
| `docs/user-guide.md` | Players | Beginner mode, presets, hotkeys, kill switch, troubleshooting |
| `docs/authoring.md` | Shader authors | Mix builder, snippet format, `MixContext` reference, `.fx` compatibility, worked examples |
| `docs/architecture.md` | Contributors | This spec, kept current, with the architecture diagram |
| `docs/dev-setup.md` | Contributors | Two-Mac setup, Tailscale, Screen Sharing, deploy loop, `mmctl` reference |
| `docs/decisions/` | Contributors | One short page per significant decision (loader/core split, weak load, fused builder shaders) |
| `CONTRIBUTING.md`, `CHANGELOG.md` | Contributors and players | Code style and PR process; plain-language changes per release |

**Writing rules.** Plain language and short sentences. Every command is copy-pasteable. UI steps get screenshots. Docs change in the same pull request as the code they describe, and CI checks links and compiles every snippet example in `docs/authoring.md` with `xcrun metal`.

**Definition of done.** A milestone is finished only when its docs pages are updated alongside the code.

## Milestones

The first milestone is a one-evening spike on the test Mac that proves the game still launches from the EA app after being re-signed. If it fails, the loading design changes before any other code is written.

| # | Milestone | Machine | Done when |
| --- | --- | --- | --- |
| M0 | Re-sign spike | Test Mac | With Sims saves backed up and EA auto-update paused, the game re-signed ad hoc by scripts/m0-resign.sh (no dylib yet) launches from the EA app and plays; original restored afterwards |
| M1 | Hello injection | Dev Mac | Loader and core load into the test host; frame counter appears in logs; kill switch works |
| M2 | First effect | Dev Mac | Present hook draws a colour-invert pass in the test host; fail-open verified with a broken shader |
| M3 | Effect chain | Dev Mac | Several native `.metal` effects chained, with hot reload and per-effect GPU timing |
| M4 | Overlay and control | Dev Mac | ImGui overlay with input capture; `mmctl` working over the socket |
| M4b | Authoring | Dev Mac, then test Mac | Beginner and Advanced modes, Mix builder with the non-depth blocks, snippet editor, bundled presets tuned on the test Mac; user guide and authoring docs drafted |
| M5 | In-game | Test Mac | Installer patches the real game; M2 to M4 work in Sims 4; first pass logs pulled back |
| M6 | `.fx` support | Dev Mac, then test Mac | Simple community effects (LUT, vibrance, sharpen) translate and run; ReShade presets import |
| M7 | Depth | Dev Mac (pass logs), then test Mac | Correct depth picked automatically in Sims 4; a DOF effect works; force-store path tested |
| M8 | Public release | Both | Smoke checklist passes; docs, license notices, notarized installer; first GitHub release |

Stretch after v1: effects under the UI, `MTLBinaryArchive` caching, a preset browser.

## Licensing, distribution, risks and open questions

**Licensing.** MetalMix's own code under MIT. Third-party notices shipped with every release: reshadefx (BSD-3-Clause), SPIRV-Cross (Apache-2.0), Dear ImGui (MIT). The project name must not use "ReShade" or "GShade", which belong to others, and no EA files are ever redistributed; the installer only patches the user's own copy.

**Distribution.** GitHub Releases with the installer app. Notarizing the installer needs an Apple Developer ID (paid yearly membership); the patched game itself cannot be notarized. Without a Developer ID, releases ship with instructions for clearing Gatekeeper quarantine.

**Risks**

| Risk | Impact | Mitigation |
| --- | --- | --- |
| EA app rejects or auto-repairs a re-signed game | Blocks the loading design | M0 spike first; fallback is a launcher that starts the executable with `DYLD_INSERT_LIBRARIES` |
| Depth not stored on Apple Silicon | No depth effects | Force-store path, opt-in, cost shown |
| Game updates remove the patch | Effects vanish until re-patched | Weak load means a vanilla game, never a crash; installer re-patches |
| Effects tint the game UI | Looks worse than Windows ReShade | Before-UI injection mode (stretch) |
| Dev and test GPUs differ | Bugs that only show in-game | Run test host on both Macs each milestone |
| Private Metal classes change in a macOS update | Hooks miss | Runtime discovery, never hardcoded names; hook failure falls back to vanilla |
| Disrupting the partner's Mac | Lost goodwill, lost test device | Kill switch, crash guard, one-folder footprint, uninstall script |
| Some `.fx` effects cannot translate | Partial preset support | Track pass rate in CI; document unsupported effects |
| Another program plants a dylib in the MetalMix folder | Malicious code runs inside the game | Release loader only loads a core whose SHA-256 matches the hash the installer stored in the app bundle |

**Open questions**

- [ ] Exact app path, and does the EA app check the game's signature at launch? (answered by M0)
- [ ] Is the name MetalMix free on GitHub and in the Sims modding scene?
- [ ] Default hotkeys that do not clash with Sims 4 bindings.
- [ ] Names and looks for the bundled presets, tuned with the partner.
- [ ] Does a GPU capture from the M4 replay on the M2? (check during M1)

Resolved: dev Mac is an M2 on macOS 27; test Mac is a MacBook Air M4 on macOS 15.6; the game runs as the arm64 build from the EA app; the partner is OK with Remote Login and Screen Sharing; Parsec is the main viewer; minimum supported macOS is 15; the project is named MetalMix.
