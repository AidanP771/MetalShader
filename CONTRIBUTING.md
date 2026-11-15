# Contributing to MetalMix

Thanks for helping. MetalMix runs inside other people's games, so the bar is
"safe and easy to understand" before "clever".

## Before you start

1. Read `docs/architecture.md`, at least the overview and the section you will
   touch.
2. Set up your machine with `docs/dev-setup.md`.
3. For anything bigger than a small fix, open an issue first so the approach can
   be agreed.

## Branches

- `main`: released or release-ready code only.
- `dev`: integration branch. Pull requests target `dev`.
- Feature branches: `feature/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.

## Pull requests

Use the template. Every pull request says:

- **What** changed and **why**.
- **How it was tested**, and on which Mac (chip and macOS version). Test host
  only, or in the game too.
- **Docs** updated, or why none were needed.

CI must pass: build (dev and release), formatting check and script syntax check.

## Code style

See the "Code style" section of `CLAUDE.md`; it applies to everyone. In short:
clang-format, a header comment on every file, explained swizzles, spelled-out
names, named constants with units.

## Commit messages

Short imperative summary, then a blank line and the why if it is not obvious:

```
Add crash guard to loader

Two failed launches in a row now disable MetalMix until the user
removes the marker, so a bad build cannot make the game unplayable.
```

## Testing on a real game

Never test on someone's game without running `scripts/start-test-session.command`
first. It backs up their saves. See `docs/testing.md`.
