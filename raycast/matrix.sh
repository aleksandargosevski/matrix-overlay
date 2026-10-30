#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Matrix
# @raycast.mode silent
# @raycast.icon 🟩
# @raycast.packageName Matrix Overlay
# @raycast.description Show Matrix rain overlay. Move the mouse or press any key to dismiss.

BIN="${0:A:h:h}/bin/matrix-overlay"
[[ -x "$BIN" ]] || { echo "Run scripts/build.sh first"; exit 1; }
nohup "$BIN" >/dev/null 2>&1 &
