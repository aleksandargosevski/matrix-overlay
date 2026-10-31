#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Matrix Typer
# @raycast.mode silent
# @raycast.icon 🟩
# @raycast.packageName Matrix Overlay
# @raycast.description Show the typer animation regardless of config.

BIN="${0:A:h:h}/bin/matrix-overlay"
[[ -x "$BIN" ]] || { echo "Run scripts/build.sh first"; exit 1; }
nohup "$BIN" --animation typer >/dev/null 2>&1 &
