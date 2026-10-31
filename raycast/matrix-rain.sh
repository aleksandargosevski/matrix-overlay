#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Matrix Rain
# @raycast.mode silent
# @raycast.icon 🟩
# @raycast.packageName Matrix Overlay
# @raycast.description Show the rain animation regardless of config.

BIN="${0:A:h:h}/bin/matrix-overlay"
[[ -x "$BIN" ]] || { echo "Run scripts/build.sh first"; exit 1; }
nohup "$BIN" --animation rain >/dev/null 2>&1 &
