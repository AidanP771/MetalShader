# Developer setup

MetalMix is built on one Mac (the dev Mac) and tested on another that has The
Sims 4 (the test Mac). This page sets up both.

| | Dev Mac | Test Mac |
| --- | --- | --- |
| Hardware | M2 | MacBook Air M4 |
| macOS | 27 | 15.6 |
| Needs | Xcode, CMake, Ninja, Tailscale | Tailscale, Parsec, the MetalMix scripts |
| Has the game | No | Yes (arm64 build from the EA app) |

## 1. Dev Mac

```sh
xcode-select --install          # or install full Xcode for GPU captures
brew install cmake ninja shellcheck
pipx install clang-format==23.1.5   # same version as CI
git clone <repo-url> metalmix && cd metalmix
cmake --preset dev
cmake --build --preset dev
```

The build sets the deployment target to macOS 15.0 so everything runs on the
test Mac. Do not use newer APIs without an availability check.

**Keep the checkout out of iCloud Drive.** If "Desktop & Documents Folders" is
on in iCloud settings, macOS stamps Finder information onto every new `.app`
folder under `~/Documents`. The build clears it before signing, so the test
host still builds and runs, but `codesign --verify` on `testhost.app` fails
afterwards and iCloud uploads the whole `build/` folder. A folder such as
`~/Developer/metalmix` avoids both.

### Try it on the test host

```sh
scripts/inject-testhost.sh
```

In a second terminal:

```sh
log stream --predicate 'subsystem == "io.metalmix"' --level debug
```

You should see the loader start, then the core start. The test host window
shows a spinning triangle.

## 2. Test Mac

1. **Tailscale:** install it and join the same tailnet as the dev Mac. Tailscale
   only provides a private network between the two Macs; it does not share the
   screen.
2. **Remote Login:** System Settings > General > Sharing > Remote Login on,
   allowed for the account that plays the game.
3. **Parsec:** already set up. It is the main way to watch the game. Screen
   Sharing (System Settings > General > Sharing > Screen Sharing) is the backup.
4. **MetalMix scripts:** copy the `scripts/` folder to the test Mac, for example
   to `~/MetalMix-scripts/`. `start-test-session.command`, `mm-report.command` and
   `mm-update.command` can be double-clicked.
5. **App Management:** the first time a script re-signs the game, macOS may ask
   to let Terminal modify apps. Allow it under System Settings > Privacy &
   Security > App Management.

## 3. SSH from the dev Mac

Add this to `~/.ssh/config` on the dev Mac, using the test Mac's Tailscale name:

```
Host test-mac
    HostName <test-mac-tailscale-name>
    User <test-account-name>
```

Then set up key login once:

```sh
ssh-copy-id test-mac
ssh test-mac 'echo connected'
```

## 4. Day-to-day loop

```sh
scripts/deploy.sh                  # build, copy core + mmctl + bundled shaders
ssh test-mac '"$HOME/Library/Application Support/MetalMix/bin/mmctl" status'
ssh test-mac log stream --predicate "'subsystem == \"io.metalmix\"'" --level debug
scripts/pull-crashes.sh            # crash reports into reports/crashes/
```

`deploy.sh` replaces the core with an atomic rename, so a running game keeps the
old core until it is relaunched. It never touches the game, saves, or the
user's own shaders and presets.

## 5. Async testing through git

When you are not both online:

- **Builds:** CI (`.github/workflows/ci.yml`) builds every push and pull
  request. A push to `dev` also replaces the rolling `dev-latest` pre-release
  with a fresh `metalmix-dev.tar.gz`. To publish from any other branch, open
  the repo's Actions tab, pick **CI**, choose **Run workflow**, select the
  branch and tick **Publish**. Or from the dev Mac:

  ```sh
  gh workflow run ci.yml --ref main -f publish=true
  ```

  `mm-update.command` on the test Mac downloads and installs it (after backing
  up saves). Set `MM_RELEASE_REPO` to `owner/repo` first, for example
  `AidanP771/MetalShader`. The archive is made by `scripts/package-build.sh`,
  the same script `deploy.sh` uses, so both routes install identical files.
  The download uses plain `curl`, so it only works while the repo is public.
- **Reports:** create a private `metalmix-testbench` repo. On the test Mac,
  clone it to `~/metalmix-testbench` using a deploy key with write access to
  that repo only. After testing, `mm-report.command` collects logs, screenshots
  and crash reports into `reports/<date>_<computer>/`, commits and pushes. On
  the dev Mac, `git pull` in your clone of the testbench repo.

Logs can contain usernames and file paths, so they never go in the public
MetalMix repo.

## 6. GPU captures

Dev builds of the patched game include the `MetalCaptureEnabled` key. Use
`mmctl capture` (from M4) to save a `.gputrace` and copy it to the dev Mac. A
capture from the M4 may not replay on the M2; if not, install Xcode on the test
Mac for capture sessions.
