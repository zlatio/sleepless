---
name: sleepless
description: Keep the Mac awake through the Sleepless app's `sleepless` CLI. Use before long-running work that idle sleep would interrupt (builds, test suites, downloads, overnight jobs), when the user asks to keep the Mac awake, let it sleep, or what is keeping it awake, and when setting up Sleepless's Claude Code hooks.
---

# Sleepless

Sleepless is a macOS menu bar app that keeps the Mac awake with named holds. The Mac stays awake while any hold exists. A hold ends when its time runs out or the process it watches exits. The app's binary is also the `sleepless` CLI, and `sleepless --help` prints the full syntax.

## Find the binary

```sh
command -v sleepless || ls /Applications/Sleepless.app/Contents/MacOS/Sleepless 2>/dev/null || { pid=$(pgrep -xo Sleepless) && ps -o comm= -p "$pid"; }
```

This prints the binary's absolute path. The last lookup finds the running app wherever it lives. Each Bash tool call starts a fresh shell, so write that path into every later command. Below, `sleepless` stands for it.

If it prints nothing, Sleepless isn't installed. Tell the user. `caffeinate -i COMMAND` covers a single command without it.

## Pick the hold

A Bash tool call's shell exits when the call returns, so a hold on `$$` ends right away. Tie each hold to the work itself:

- One long command, in the foreground or with `run_in_background`: `sleepless run --name NAME -- COMMAND ARGS...`. The hold lasts as long as the command, and `run` exits with the command's exit code. Wrap pipes and `&&` chains in `sh -c '...'`, or the outer shell runs everything after the first command without the hold.
- A detached process started with `nohup ... &`: `sleepless hold NAME --while $!` in the same call.
- Several steps in a row, or remote work with no local PID such as CI or a deploy: `sleepless hold NAME --for 2h` before and `sleepless release NAME` after. Running the same `hold` again restarts the clock.
- The user asks to keep the Mac awake: `sleepless on`, plus `--for` if they gave a duration. This is the popover's own hold, named `manual`.
- The user asks to let it sleep: `sleepless off`.
- The user asks what is keeping it awake: `sleepless status`, or `--json` to parse it. Sleepless only knows its own holds. `pmset -g assertions` lists every app's.

If `status` during your turn lists a `claude-<pid>` hold, the Claude Code hooks are on and already cover your turns and background tasks. Then only detached processes and work that continues after the session need a hold of their own.

## Rules

- Name holds after the task, like `ios-build` or `db-migration`. A hold replaces any hold with the same name, and `run` defaults to the command's basename, so two parallel `run -- npm ...` calls share one hold. Leave `manual` and `claude-*` holds to the user and the hooks.
- Clean up with `release NAME`. `off` ends every hold, including the user's and other agents', so run it only when the user asks for it.
- `--for` takes 15m, 30m, 1h or 2h, and `on` also takes `forever`. `hold` needs `--while`, `--for`, or both, so it can't last forever. With both, it ends at whichever comes first.
- `--while` needs a PID that is still running, or the command fails.
- Pass `--display` or `--no-display` only when the user asks. They change the saved setting that applies to every hold. `on --for` also changes the popover's saved duration.

## Limits

- Sleepless blocks idle sleep only. Closing the lid on battery still puts the Mac to sleep.
- The CLI reaches the app through a Mach port in the user's login session, so it can't reach it over SSH.
- `on`, `hold` and `run` start the app if it isn't running. `status`, `off` and `release` don't, and `status` then prints `Sleeping normally (Sleepless isn't running)` and exits 0.

## Claude Code hooks

The hooks hold `claude-<pid>` from each prompt until a turn ends with no background tasks running, the session ends, or Claude exits. To set them up, add this entry to the `UserPromptSubmit`, `Stop` and `SessionEnd` arrays under `hooks` in `~/.claude/settings.json`, keeping any entries already there:

```json
{"hooks": [{"type": "command", "command": "/absolute/path/to/Sleepless claude-hook $PPID"}]}
```

Use the absolute path from "Find the binary". Hook shells may not have `~/.local/bin` on PATH.
