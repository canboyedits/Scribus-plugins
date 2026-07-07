#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/development/scribus-v2"
PLUGIN_NAME="codewindow"
PLUGIN_SRC="$ROOT/plugin/$PLUGIN_NAME"
PLUGIN_DEST="$ROOT/src/scribus/plugins/tools/$PLUGIN_NAME"
TOOLS_CMAKE="$ROOT/src/scribus/plugins/tools/CMakeLists.txt"

if [ ! -d "$PLUGIN_SRC" ]; then
  echo "ERROR: plugin source not found: $PLUGIN_SRC"
  exit 1
fi

if [ ! -f "$TOOLS_CMAKE" ]; then
  echo "ERROR: Scribus source not found or not extracted: $TOOLS_CMAKE"
  echo "Run ./scribus-mac-prod.sh rebuild-fresh first, then run this script."
  exit 1
fi

mkdir -p "$PLUGIN_DEST"
rsync -a --delete "$PLUGIN_SRC/" "$PLUGIN_DEST/"

echo "Synced plugin source:"
echo "  from: $PLUGIN_SRC/"
echo "  to:   $PLUGIN_DEST/"

if grep -Eq '^[[:space:]]*add_subdirectory[[:space:]]*\([[:space:]]*codewindow[[:space:]]*\)' "$TOOLS_CMAKE"; then
  echo "tools/CMakeLists.txt already contains add_subdirectory(codewindow)."
else
  printf '\nadd_subdirectory(codewindow)\n' >> "$TOOLS_CMAKE"
  echo "Added add_subdirectory(codewindow) to: $TOOLS_CMAKE"
fi
