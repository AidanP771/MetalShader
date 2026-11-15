# fxc-metal (planned, M6)

Offline translator from ReShade `.fx` effects to Metal Shading Language, using
the same `mmfx` library the core uses at runtime.

```sh
fxc-metal input.fx -o output.metal
```

Used in CI to translate every effect in the target shader collections and then
compile the result with `xcrun metal`, so the translation pass rate is tracked
per build.
