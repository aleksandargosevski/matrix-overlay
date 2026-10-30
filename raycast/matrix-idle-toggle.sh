#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Toggle Matrix Idle
# @raycast.mode compact
# @raycast.icon 🟢
# @raycast.packageName Matrix Overlay
# @raycast.description Enable or disable the idle trigger.

LABEL="dev.matrix-overlay.idle"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
S="gui/$(id -u)/$LABEL"
[[ -f "$PLIST" ]] || { echo "Run scripts/install.sh first"; exit 1; }
if launchctl print "$S" >/dev/null 2>&1; then
  launchctl bootout "$S" && echo "Matrix idle: OFF"
else
  launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "Matrix idle: ON"
fi
