#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/development/scribus-v2"
BUILD="$ROOT/build"
INSTALL="$ROOT/install"
LOGS="$ROOT/logs"

mkdir -p "$LOGS"
cd "$ROOT"

"$ROOT/scripts/sync-codewindow-plugin.sh"

if [ ! -f "$BUILD/build.ninja" ]; then
  echo "ERROR: build folder is not configured yet."
  echo "Run: ./scribus-mac-prod.sh rebuild-fresh"
  exit 1
fi

echo

echo "Building codewindow plugin..."
cmake --build "$BUILD" --target codewindow --parallel 6 2>&1 | tee "$LOGS/build-codewindow.log"

echo

echo "Installing codewindow plugin..."
cmake --install "$BUILD" 2>&1 | tee "$LOGS/install-codewindow.log"

echo

echo "Installed plugin files:"
find "$INSTALL" -iname '*codewindow*' -print || true

echo

echo "Done. Launch Scribus with:"
echo "open \"$INSTALL/Scribus1.7.2.app\""
