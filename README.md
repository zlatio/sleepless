# Sleepless ☕️

A tiny native macOS menu bar app that keeps your Mac awake.

Built with SwiftUI (`MenuBarExtra`) and IOKit power assertions — the same
mechanism `caffeinate` uses, no hacks, no synthetic key presses.

## Features

- One-click **Keep My Mac Awake / Let My Mac Sleep** toggle from the menu bar
- Optional auto-off timer: 15 min, 30 min, 1 h, 2 h, or indefinitely (∞)
- Live countdown in the popover
- Choice between keeping the **display** on or letting the screen sleep
  while the system stays awake
- Menu-bar-only (no Dock icon); icon switches ☕️ ↔ 💤 with state

## Build & run

```bash
./build-app.sh      # builds Sleepless.app in the project root
open Sleepless.app
```

Or during development:

```bash
swift run
```

To keep it around, move `Sleepless.app` to `/Applications` and (optionally)
add it to **System Settings → General → Login Items** to launch at login.

## Project layout

```
Package.swift                      Swift Package manifest
Sources/Sleepless/
  SleeplessApp.swift               App entry point + MenuBarExtra scene
  MenuView.swift                   Popover UI
  SleepManager.swift               IOPMAssertion lifecycle + timer
build-app.sh                       Packages the release binary as a .app
```
