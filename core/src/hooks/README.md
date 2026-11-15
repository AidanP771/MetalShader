# hooks

Finds Metal's concrete classes at runtime and swizzles the methods MetalMix
needs. Every hook goes through `MMSwizzleInstanceMethod` (`MMSwizzle.h`).

## Planned hooks

| Hook | Why | Milestone |
| --- | --- | --- |
| `presentDrawable:` (and `atTime:`, `afterMinimumDuration:`) | Frame boundary: run effects, then present | M1 |
| `-[CAMetalLayer nextDrawable]` | Track layer, drawable size and pixel format | M2 |
| `-[CAMetalLayer setFramebufferOnly:]` | Force `NO` so the frame can be sampled | M2 |
| `renderCommandEncoderWithDescriptor:` | Record each render pass for the pass log | M7 |
| `-[MTLRenderCommandEncoder endEncoding]` | Copy depth at pass end if needed | M7 |
| `newTextureWithDescriptor:` | Track depth textures, optional force-store | M7 |
| `-[NSApplication sendEvent:]` | Hotkeys and overlay input | M4 |

## Rules

- Never hardcode private class names. Discover them from live objects.
- Every hook calls the original on every path, including errors.
- A thread-local flag stops MetalMix's own Metal calls re-entering its hooks.
- Each swizzle has a comment saying which Metal behaviour it relies on.

## Must never

- Throw out of a hook. Wrap bodies in `@try` and C++ `try`.
- Allocate, compile or touch files on the render thread.
