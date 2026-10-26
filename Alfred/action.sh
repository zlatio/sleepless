#!/bin/zsh
# Runs the action picked in the Script Filter, or "toggle" from the hotkey. The output becomes the notification.
case $1 in
  toggle)
    if ./sleepless status --json | grep -q '"active":true'; then
      ./sleepless off
    else
      ./sleepless on
    fi
    ;;
  release\ *)
    ./sleepless release "${1#release }"
    ;;
  *)
    ./sleepless ${=1}
    ;;
esac 2>&1
