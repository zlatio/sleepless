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

The app is a universal binary that runs on Apple silicon and Intel Macs.
`Sleepless.zip` contains the signed `Sleepless.app`. The signature is ad hoc,
so on another Mac Gatekeeper blocks the first launch. Allow it with
**Open Anyway** in **System Settings → Privacy & Security**.

After editing the icon, run `Icon/build-icon.sh` before `./build-app.sh`.

To keep it around, move `Sleepless.app` to `/Applications` and (optionally)
add it to **System Settings → General → Login Items** to launch at login.

## Project layout

```
Package.swift                      Swift Package manifest
Sources/Sleepless/
  SleeplessApp.swift               App entry point + MenuBarExtra scene
  MenuView.swift                   Popover UI
  SleepManager.swift               IOPMAssertion lifecycle, timer, saved settings
Icon/
  AppIcon.icon/                    Icon Composer source
  build-icon.sh                    Regenerates Assets.car + AppIcon.icns (needs Xcode 26+)
  Assets.car, AppIcon.icns         Compiled icon, copied into the .app
build-app.sh                       Builds the universal .app and zips it
```
