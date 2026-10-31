#!/bin/zsh
# Kompajlira overlay u bin/matrix-overlay
set -e
ROOT="${0:A:h:h}"
mkdir -p "$ROOT/bin"
swiftc -O -swift-version 5 "$ROOT"/overlay/*.swift -o "$ROOT/bin/matrix-overlay"
echo "Built: $ROOT/bin/matrix-overlay"
