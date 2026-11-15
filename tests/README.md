# tests

| Folder | What | Runs on | Starts in |
| --- | --- | --- | --- |
| `unit/` | Config and preset parsing, depth scoring against recorded pass logs, Mach-O patcher on fixture binaries | Dev Mac, CI | M3 |
| `translation/` | Every `.fx` in the target shader repos through `fxc-metal`, then `xcrun metal` | Dev Mac, CI | M6 |
| `golden/` | Bundled effects run on reference images, compared within a tolerance | Dev Mac (needs a GPU) | M3 |
| `fixtures/passlogs/` | Pass logs recorded in the game with `mmctl dump-passes` | Used by unit tests | M5 |

Integration testing uses `testhost/` with `scripts/inject-testhost.sh`. Device
testing on the test Mac follows `docs/testing.md`.

Fixtures are kept small. Do not commit GPU captures or anything over a few MB.
