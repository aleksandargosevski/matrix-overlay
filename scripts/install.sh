#!/bin/zsh
# Build + instalira launchd agenta koji pali overlay posle N sekundi neaktivnosti.
# Upotreba: scripts/install.sh [idle_sekundi] [dodatni argumenti za overlay...]
set -e
ROOT="${0:A:h:h}"
LABEL="dev.matrix-overlay.idle"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
IDLE="${1:-60}"; shift 2>/dev/null || true

"$ROOT/scripts/build.sh"

EXTRA=""
for a in "$@"; do EXTRA+="    <string>$a</string>\n"; done

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
    <string>--idle</string><string>$IDLE</string>
$(printf "$EXTRA")  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardErrorPath</key><string>${TMPDIR:-/tmp}/matrix-overlay.log</string>
</dict>
</plist>
PLIST
plutil -lint -s "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL (idle ${IDLE}s)"
