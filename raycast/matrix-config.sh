#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Edit Matrix Config
# @raycast.mode silent
# @raycast.icon ⚙️
# @raycast.packageName Matrix Overlay
# @raycast.description Open config.toml and typer.txt

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matrix-overlay"
[[ -f "$DIR/config.toml" ]] || "${0:A:h:h}/bin/matrix-overlay" --init-config >/dev/null
open -t "$DIR/config.toml" "$DIR/typer.txt"
