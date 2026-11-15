# depth

Finds the game's scene depth buffer. Starts in M7, but the pass log it relies on
is recorded from M5 so the work can happen offline.

## Pass log

For each render pass: attachments, sizes, pixel formats, load and store actions,
draw call count. `mmctl dump-passes` writes a few frames as JSON. Logs pulled
from the test Mac are kept in `tests/fixtures/passlogs/`.

## Scoring a candidate

- Size matches the drawable (or drawable times the game's resolution scale).
- Cleared once per frame, used by the pass with the most draws.
- Stored at pass end. Unstored depth cannot be read later.
- Same choice as last frame (stability bonus).

## Apple Silicon

Games may skip storing depth (`DontCare` store action or `memoryless` storage).
Force-store changes that for the chosen texture only. It costs bandwidth, so it
is opt-in per preset and its cost is shown in the overlay.
