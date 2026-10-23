# Sleepless ☕️

A tiny native macOS menu bar app that keeps your Mac awake.

Built with SwiftUI (`MenuBarExtra`) and IOKit power assertions — the same
mechanism `caffeinate` uses, no hacks, no synthetic key presses.

Sleepless blocks idle sleep only. Closing the lid on battery still puts the
Mac to sleep, same as with `caffeinate`.

## Features

- One-click **Keep My Mac Awake / Let My Mac Sleep** toggle from the menu bar
- Optional auto-off timer: 15 min, 30 min, 1 h, 2 h, or indefinitely (∞)
- Live countdown in the popover
- Choice between keeping the **display** on or letting the screen sleep
  while the system stays awake
- Remembers the chosen duration and display setting between launches
- Command line control for scripts and agents, with Claude Code hooks
- Menu-bar-only (no Dock icon); icon switches ☕️ ↔ 💤 with state

## Build & run

```bash
./build-app.sh      # builds Sleepless.app and Sleepless.zip in the project root
open Sleepless.app
```

Or during development:

```bash
swift run
```

`swift run` exits right away if the built app is already running, because
only one copy can own the control port.

The app is a universal binary that runs on Apple silicon and Intel Macs.
`Sleepless.zip` contains the signed `Sleepless.app`. The signature is ad hoc,
so on another Mac Gatekeeper blocks the first launch. Allow it with
**Open Anyway** in **System Settings → Privacy & Security**.

After editing the icon, run `Icon/build-icon.sh` before `./build-app.sh`.

To keep it around, move `Sleepless.app` to `/Applications` and (optionally)
add it to **System Settings → General → Login Items** to launch at login.

## Command line and agents

The app's binary is also a command line tool. To put it on your PATH:

```bash
ln -s /Applications/Sleepless.app/Contents/MacOS/Sleepless ~/.local/bin/sleepless
```

```
sleepless status [--json]
sleepless on [--for 15m|30m|1h|2h|forever] [--while PID] [--display|--no-display]
sleepless off
sleepless hold NAME (--while PID | --for 15m|30m|1h|2h) [--json]
sleepless release NAME
sleepless run [--name NAME] -- COMMAND [ARGS...]
sleepless claude-hook PID
```

Each reason to stay awake is a named hold, and the Mac stays awake while any
hold exists. A hold ends when its time runs out or the process it watches
exits. `on` and `off` do what the popover button does, and `off` releases
every hold. `hold` and `run` give scripts and agents holds of their own.
`on`, `hold`, `run` and `claude-hook` start the app if it isn't running.
Commands exit with 0 on success and 1 on error. `run` exits with its
command's code.

The CLI talks to the app through a Mach port that belongs to your login
session, so it can't reach the app from an SSH session.

### Claude Code hooks

Add this to `~/.claude/settings.json`. It uses the full path because hook
shells may not have `~/.local/bin` on PATH.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/Applications/Sleepless.app/Contents/MacOS/Sleepless claude-hook $PPID"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/Applications/Sleepless.app/Contents/MacOS/Sleepless claude-hook $PPID"}]}
    ],
    "SessionEnd": [
      {"hooks": [{"type": "command", "command": "/Applications/Sleepless.app/Contents/MacOS/Sleepless claude-hook $PPID"}]}
    ]
  }
}
```

Each prompt holds `claude-<pid>` until Claude finishes a turn with no
background tasks still running, the session ends, or the Claude process exits.

## Project layout

```
Package.swift                      Swift Package manifest
Sources/Sleepless/
  SleeplessApp.swift               Entry point (app or CLI) + MenuBarExtra scene
  MenuView.swift                   Popover UI
  SleepManager.swift               Holds, IOPMAssertion lifecycle, saved settings
  ControlPort.swift                CLI-to-app message format + the app's listener
  CLI.swift                        The sleepless command line
Icon/
  AppIcon.icon/                    Icon Composer source
  build-icon.sh                    Regenerates Assets.car + AppIcon.icns (needs Xcode 26+)
  Assets.car, AppIcon.icns         Compiled icon, copied into the .app
build-app.sh                       Builds the universal .app and zips it
```
