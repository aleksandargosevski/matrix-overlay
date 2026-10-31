#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Matrix
# @raycast.mode silent
# @raycast.icon 🟩
# @raycast.packageName Matrix Overlay
# @raycast.description Show the overlay. Move the mouse or press any key to dismiss.
# @raycast.argument1 { "type": "dropdown", "placeholder": "Animation", "optional": true, "data": [{"title": "From config", "value": ""}, {"title": "Rain", "value": "rain"}, {"title": "Typer", "value": "typer"}, {"title": "Random", "value": "random"}] }

BIN="${0:A:h:h}/bin/matrix-overlay"
[[ -x "$BIN" ]] || { echo "Run scripts/build.sh first"; exit 1; }
ARGS=()
[[ -n "$1" ]] && ARGS=(--animation "$1")
nohup "$BIN" "${ARGS[@]}" >/dev/null 2>&1 &
