#!/bin/zsh
# Build, create config (if missing) and install the launchd idle agent.
# Usage: scripts/install.sh [idle_seconds]   (idle_seconds updates config.toml)
set -e
ROOT="${0:A:h:h}"
LABEL="dev.matrix-overlay.idle"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matrix-overlay"

"$ROOT/scripts/build.sh"
"$ROOT/bin/matrix-overlay" --init-config

if [[ -n "$1" ]]; then
  sed -i '' -E "s/^idle_seconds *=.*/idle_seconds = $1         # idle trigger delay (used by the launchd agent)/" "$CONFIG_DIR/config.toml"
  echo "idle_seconds = $1"
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ROOT/bin/matrix-overlay</string>
    <string>--daemon</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardErrorPath</key><string>${TMPDIR:-/tmp}/matrix-overlay.log</string>
</dict>
</plist>
PLIST
plutil -lint -s "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
for i in {1..10}; do
  launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null && break
  sleep 0.5
done
launchctl print "gui/$(id -u)/$LABEL" >/dev/null
echo "Installed $LABEL. Config: $CONFIG_DIR/config.toml"
