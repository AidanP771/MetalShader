# mmctl

Sends one command to a running MetalMix core and prints the reply. Works only
with Dev builds, which run the control server on
`~/Library/Application Support/MetalMix/ctl.sock`.

```sh
mmctl status                       # on the same Mac as the game
ssh test-mac mmctl status          # from the dev Mac
mmctl --socket /tmp/ctl.sock status
```

Exit codes: `0` ok, `1` the core replied with an error, `2` usage problem,
`3` MetalMix is not reachable (game not running, or a Release build).

## Commands

The server side is built in M4. This list is the plan; keep it in sync with
`core/src/control/`.

| Command | Does |
| --- | --- |
| `status` | Core version, GPU, drawable size, active preset, failures |
| `reload [effect]` | Recompile one or all effects |
| `enable <effect>` / `disable <effect>` | Toggle an effect |
| `set <effect>.<param> <value>` | Change a parameter |
| `mode beginner` / `mode advanced` | Switch overlay mode |
| `dump-passes [frames]` | Write the pass log as JSON (for depth work) |
| `depth list` / `depth pick <id>` | Inspect and choose depth candidates |
| `capture` | Save a `.gputrace` with `MTLCaptureManager` |
| `screenshot` | Save a post-effect PNG to `~/Pictures/MetalMix/` |
| `log-level <level>` | Change logging verbosity |

## Installing on the test Mac

`scripts/deploy.sh` copies `mmctl` to `~/Library/Application Support/MetalMix/bin/`.
Add that folder to the test account's `PATH`, or call it by full path.
