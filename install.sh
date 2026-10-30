#!/bin/zsh
# One-line installer:
#   curl -fsSL https://raw.githubusercontent.com/aleksandargosevski/matrix-overlay/main/install.sh | zsh
# Env: MATRIX_DIR (default ~/.local/share/matrix-overlay), MATRIX_IDLE (default 60, 0 = no idle agent)
set -e
REPO="https://github.com/aleksandargosevski/matrix-overlay.git"
DIR="${MATRIX_DIR:-$HOME/.local/share/matrix-overlay}"
IDLE="${MATRIX_IDLE:-60}"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Starting installer..."
  xcode-select --install || true
  echo "Re-run this command once the installation finishes."
  exit 1
fi

if [[ -d "$DIR/.git" ]]; then
  echo "Updating $DIR"
  git -C "$DIR" pull --ff-only -q
else
  echo "Cloning into $DIR"
  mkdir -p "${DIR:h}"
  git clone -q "$REPO" "$DIR"
fi

if [[ "$IDLE" == "0" ]]; then
  "$DIR/scripts/build.sh"
else
  "$DIR/scripts/install.sh" "$IDLE"
fi

cat <<MSG

Done. Last step (Raycast hotkey):
  Raycast → Settings → Extensions → + → Add Script Directory → $DIR/raycast
  then assign a hotkey to "Matrix".
Test now: $DIR/bin/matrix-overlay
MSG
