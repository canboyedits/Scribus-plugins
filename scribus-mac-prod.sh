#!/usr/bin/env bash
set -euo pipefail

ROOT="${SCRIBUS_V2_ROOT:-$HOME/Desktop/development/scribus-v2}"
DOWNLOADS="$ROOT/downloads"
SRC="$ROOT/src"
BUILD_DIR="$ROOT/build"
INSTALL_DIR="$ROOT/install"
LOGS="$ROOT/logs"
ARCHIVE="$DOWNLOADS/scribus-1.7.2.tar.xz"
URL="https://sourceforge.net/projects/scribus/files/scribus-devel/1.7.2/scribus-1.7.2.tar.xz/download"

mkdir -p "$ROOT" "$DOWNLOADS" "$LOGS"
cd "$ROOT"

say() { printf '\n==> %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING command: $1"; exit 1; }; }

usage() {
  cat <<USAGE
Scribus 1.7.2 macOS ARM64 production workspace helper

Usage:
  ./scribus-mac-prod.sh setup          Create docs, Brewfile, gitignore, reports. Safe.
  ./scribus-mac-prod.sh build          Install deps, download/extract source if needed, patch, build, install.
  ./scribus-mac-prod.sh rebuild-fresh  Re-extract source, patch, clean build/install, build, install.
  ./scribus-mac-prod.sh doctor         Write environment report to logs/mac-env-report.txt.
  ./scribus-mac-prod.sh lock           Write exact versions to logs/mac-version-lock.txt.
  ./scribus-mac-prod.sh audit          Write workspace audit to logs/current-workspace-audit.txt.
  ./scribus-mac-prod.sh tidy           Archive old temporary scripts/logs without touching src/build/install.
  ./scribus-mac-prod.sh clean          Remove build/install and build logs only.
  ./scribus-mac-prod.sh open           Open installed Scribus app if found.
  ./scribus-mac-prod.sh all            setup + build + doctor + lock + audit.

Default: setup

Workspace:
  $ROOT
USAGE
}

write_gitignore() {
  cat > "$ROOT/.gitignore" <<'EOF_GITIGNORE'
# Generated Scribus build workspace
/downloads/
/src/
/build/
/install/
/logs/*.log
/logs/*.txt

# macOS noise
.DS_Store

# Editors
.vscode/
.idea/

# Archives created by tidy
/_archive/
EOF_GITIGNORE
}

write_brewfile() {
  cat > "$ROOT/Brewfile" <<'EOF_BREWFILE'
# Scribus 1.7.2 macOS ARM64 development/build dependencies.
# Install with: brew bundle --file=Brewfile

brew "cmake"
brew "ninja"
brew "ccache"
brew "pkg-config"
brew "git"
brew "subversion"

brew "qt"
brew "python@3.12"

brew "cairo"
brew "freetype"
brew "fontconfig"
brew "harfbuzz"
brew "hunspell"
brew "icu4c"
brew "jpeg-turbo"
brew "libpng"
brew "libtiff"
brew "little-cms2"
brew "libxml2"
brew "boost"
brew "poppler"
brew "podofo"
brew "librevenge"

# Optional importers discovered during the current successful configure.
brew "libcdr"
brew "libfreehand"
brew "libpagemaker"
brew "libmspub"
brew "libvisio"
EOF_BREWFILE
}

write_readme() {
  cat > "$ROOT/README-mac.md" <<'EOF_README'
# Scribus 1.7.2 macOS ARM64 Build Workspace

This workspace builds Scribus 1.7.2 locally on macOS ARM64 for C++ plugin development.

Workspace path:

    ~/Desktop/development/scribus-v2

## Why this exists

The goal is to build and test custom Scribus C++ plugins against a fixed Scribus target: version 1.7.2.

Daily development happens on macOS. Windows production builds should later be produced separately on Windows x64 or CI.

## Main script

Use:

    ./scribus-mac-prod.sh setup
    ./scribus-mac-prod.sh build
    ./scribus-mac-prod.sh doctor
    ./scribus-mac-prod.sh lock
    ./scribus-mac-prod.sh audit
    ./scribus-mac-prod.sh tidy
    ./scribus-mac-prod.sh clean
    ./scribus-mac-prod.sh open

For a full from-source rebuild:

    ./scribus-mac-prod.sh rebuild-fresh

## Folder layout

    scribus-v2/
      scribus-mac-prod.sh
      README-mac.md
      Brewfile
      .gitignore
      downloads/   generated
      src/         generated Scribus 1.7.2 source
      build/       generated CMake/Ninja build files
      install/     generated installed Scribus app
      logs/        generated logs and reports
      _archive/    old temporary files moved by tidy

## Generated folders

These are generated and should not be committed:

    downloads/
    src/
    build/
    install/
    logs/
    _archive/

The reusable project is the script, Brewfile, README, and later your plugin code/docs.

## Dependencies

Main tools:

    Xcode Command Line Tools
    Homebrew
    CMake
    Ninja
    ccache
    pkg-config
    Git
    Subversion
    Apple Clang

Main libraries:

    Qt 6
    Python 3.12
    Cairo
    Freetype
    Fontconfig
    Harfbuzz
    Hunspell
    ICU
    JPEG Turbo
    libpng
    libtiff
    LittleCMS 2
    libxml2
    Boost
    Poppler
    PoDoFo
    librevenge

Optional importer libraries:

    libcdr
    libfreehand
    libpagemaker
    libmspub
    libvisio

## Local compatibility patch

The built-in Scribus PDF importer is disabled during this Mac build.

Reason: Homebrew Poppler 26.x has API changes that break Scribus 1.7.2's built-in PDF importer source.

This is acceptable for the first plugin-development target because the initial plugin only needs the Scribus app and plugin system to build and launch. Later options are:

1. Use a Poppler version compatible with Scribus 1.7.2.
2. Patch Scribus' PDF importer source for Poppler 26.x.
3. Keep the PDF importer disabled for UI/plugin development.

## Development rule

Plugin work should target Scribus 1.7.2 only unless the target version is intentionally changed.
EOF_README
}

setup_workspace() {
  say "Creating production workspace files"
  mkdir -p "$DOWNLOADS" "$SRC" "$BUILD_DIR" "$INSTALL_DIR" "$LOGS"
  write_gitignore
  write_brewfile
  write_readme
  say "Created/updated: .gitignore, Brewfile, README-mac.md"
}

install_deps() {
  say "Checking build tools"
  need brew
  need curl
  need tar
  say "Installing Homebrew dependencies from Brewfile"
  brew bundle --file="$ROOT/Brewfile"
}

find_qt() {
  if brew --prefix qt >/dev/null 2>&1; then
    QT_PREFIX="$(brew --prefix qt)"
  elif brew --prefix qt@6 >/dev/null 2>&1; then
    QT_PREFIX="$(brew --prefix qt@6)"
  else
    echo "ERROR: Qt 6 not found via Homebrew."
    exit 1
  fi
  export QT_PREFIX
}

find_python() {
  local py312=""
  py312="$(brew --prefix python@3.12 2>/dev/null || true)"
  if [ -n "$py312" ] && [ -x "$py312/bin/python3.12" ]; then
    PYTHON_EXECUTABLE="$py312/bin/python3.12"
  else
    PYTHON_EXECUTABLE="$(command -v python3)"
  fi
  export PYTHON_EXECUTABLE
}

make_prefix_paths() {
  PREFIXES=()
  add_prefix() {
    local formula="$1"
    if brew --prefix "$formula" >/dev/null 2>&1; then
      PREFIXES+=("$(brew --prefix "$formula")")
    fi
  }

  for formula in qt qt@6 cairo freetype fontconfig harfbuzz hunspell icu4c jpeg-turbo libpng libtiff little-cms2 libxml2 boost poppler podofo librevenge libcdr libfreehand libpagemaker libmspub libvisio python@3.12; do
    add_prefix "$formula"
  done

  CMAKE_PREFIX_PATH="$(IFS=';'; echo "${PREFIXES[*]}")"

  PKG_PATHS=()
  for p in "${PREFIXES[@]}"; do
    [ -d "$p/lib/pkgconfig" ] && PKG_PATHS+=("$p/lib/pkgconfig")
    [ -d "$p/share/pkgconfig" ] && PKG_PATHS+=("$p/share/pkgconfig")
  done
  PKG_CONFIG_PATH="$(IFS=':'; echo "${PKG_PATHS[*]}")"

  export CMAKE_PREFIX_PATH PKG_CONFIG_PATH
}

download_source() {
  say "Downloading Scribus 1.7.2 source if missing"
  if [ ! -f "$ARCHIVE" ]; then
    curl -L -o "$ARCHIVE" "$URL"
  else
    echo "Using existing archive: $ARCHIVE"
  fi
}

extract_source_if_missing() {
  say "Extracting Scribus source if missing"
  if [ ! -f "$SRC/CMakeLists.txt" ]; then
    rm -rf "$SRC"
    mkdir -p "$SRC"
    tar -xf "$ARCHIVE" -C "$SRC" --strip-components=1
  else
    echo "Using existing source: $SRC"
  fi
}

extract_source_fresh() {
  say "Re-extracting fresh Scribus source"
  rm -rf "$SRC"
  mkdir -p "$SRC"
  tar -xf "$ARCHIVE" -C "$SRC" --strip-components=1
}

show_source_version() {
  say "Scribus source version"
  grep -n "VERSION_MAJOR\|VERSION_MINOR\|VERSION_PATCH" "$SRC/CMakeLists.txt" | head -n 10 || true
}

patch_pdf_importer() {
  say "Applying Poppler 26.x compatibility patch: disable built-in PDF importer"
  local import_cmake="$SRC/scribus/plugins/import/CMakeLists.txt"
  if [ ! -f "$import_cmake" ]; then
    echo "ERROR: cannot find $import_cmake"
    exit 1
  fi

  if grep -q "Disabled locally because Homebrew Poppler 26.x API breaks Scribus 1.7.2 PDF importer" "$import_cmake"; then
    echo "PDF importer already disabled."
    return 0
  fi

  if ! grep -Eiq '^[[:space:]]*add_subdirectory[[:space:]]*\([[:space:]]*pdf[[:space:]]*\)' "$import_cmake"; then
    echo "No active add_subdirectory(pdf) line found. Continuing."
    grep -n -i "pdf" "$import_cmake" || true
    return 0
  fi

  cp -n "$import_cmake" "$import_cmake.backup-before-disable-pdf" || true

  python3 - "$import_cmake" <<'EOF_PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text()
new = re.sub(
    r'(?im)^(\s*add_subdirectory\s*\(\s*pdf\s*\).*)$',
    r'# Disabled locally because Homebrew Poppler 26.x API breaks Scribus 1.7.2 PDF importer\n# \1',
    text,
)
if new != text:
    path.write_text(new)
    print(f"Disabled PDF importer in: {path}")
else:
    print("No change made.")
EOF_PY
}

configure_build_install() {
  need cmake
  need ninja
  need clang
  need clang++
  need pkg-config
  find_qt
  find_python
  make_prefix_paths

  say "Toolchain"
  echo "QT_PREFIX=$QT_PREFIX"
  echo "PYTHON_EXECUTABLE=$PYTHON_EXECUTABLE"
  "$PYTHON_EXECUTABLE" --version
  echo "CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH"
  echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

  say "Cleaning build/install folders"
  rm -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$LOGS"

  say "Configuring"
  cmake -S "$SRC" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
    -DQT_PREFIX="$QT_PREFIX" \
    -DPython3_EXECUTABLE="$PYTHON_EXECUTABLE" \
    -DWANT_CCACHE=ON \
    -DWANT_PCH=OFF \
    -DBUILD_OSX_BUNDLE=ON \
    2>&1 | tee "$LOGS/configure-mac.log"

  say "Building"
  cmake --build "$BUILD_DIR" --parallel 6 2>&1 | tee "$LOGS/build-mac.log"

  say "Installing"
  cmake --install "$BUILD_DIR" 2>&1 | tee "$LOGS/install-mac.log"

  say "Installed app/binary candidates"
  find "$INSTALL_DIR" -maxdepth 6 \( -iname "Scribus*.app" -o -iname "scribus" \) || true
}

build_normal() {
  setup_workspace
  install_deps
  download_source
  extract_source_if_missing
  show_source_version
  patch_pdf_importer
  configure_build_install
  lock_versions
}

build_fresh() {
  setup_workspace
  install_deps
  download_source
  extract_source_fresh
  show_source_version
  patch_pdf_importer
  configure_build_install
  lock_versions
}

doctor() {
  say "Writing environment report"
  local report="$LOGS/mac-env-report.txt"
  mkdir -p "$LOGS"
  {
    echo "SCRIBUS 1.7.2 MAC BUILD ENV REPORT"
    echo "Generated: $(date)"
    echo "Workspace: $ROOT"
    echo "============================================================"
    echo
    echo "SYSTEM"
    sw_vers 2>/dev/null || true
    uname -a
    echo "Architecture: $(uname -m)"
    sysctl -n machdep.cpu.brand_string 2>/dev/null || true
    sysctl -n hw.memsize 2>/dev/null | awk '{ printf "Memory: %.2f GB\n", $1/1024/1024/1024 }' || true
    echo
    echo "TOOLS"
    for cmd in clang clang++ cmake ninja ccache git svn pkg-config python3 curl tar; do
      if command -v "$cmd" >/dev/null 2>&1; then
        echo "FOUND: $cmd -> $(command -v "$cmd")"
        "$cmd" --version 2>/dev/null | head -n 1 || true
      else
        echo "MISSING: $cmd"
      fi
    done
    echo
    echo "HOMEBREW"
    if command -v brew >/dev/null 2>&1; then
      brew --version | head -n 2
      echo "brew prefix: $(brew --prefix)"
    else
      echo "MISSING: brew"
    fi
    echo
    echo "BREW PACKAGE VERSIONS"
    if command -v brew >/dev/null 2>&1; then
      for p in cmake ninja ccache pkg-config git subversion qt python@3.12 cairo freetype fontconfig harfbuzz hunspell icu4c jpeg-turbo libpng libtiff little-cms2 libxml2 boost poppler podofo librevenge libcdr libfreehand libpagemaker libmspub libvisio; do
        brew list --versions "$p" 2>/dev/null || echo "MISSING: $p"
      done
    fi
    echo
    echo "SCRIBUS SOURCE"
    if [ -f "$SRC/CMakeLists.txt" ]; then
      grep -n "VERSION_MAJOR\|VERSION_MINOR\|VERSION_PATCH" "$SRC/CMakeLists.txt" | head -n 10 || true
    else
      echo "No source extracted yet."
    fi
    echo
    echo "PDF IMPORTER PATCH STATUS"
    if [ -f "$SRC/scribus/plugins/import/CMakeLists.txt" ]; then
      grep -n -i "pdf" "$SRC/scribus/plugins/import/CMakeLists.txt" || true
    else
      echo "No import CMakeLists.txt yet."
    fi
    echo
    echo "APP CHECK"
    find "$INSTALL_DIR" -maxdepth 6 \( -iname "Scribus*.app" -o -iname "scribus" \) 2>/dev/null || true
  } | tee "$report"
  echo "Report saved to: $report"
}

lock_versions() {
  say "Writing version lock"
  local out="$LOGS/mac-version-lock.txt"
  mkdir -p "$LOGS"
  {
    echo "SCRIBUS 1.7.2 MAC VERSION LOCK"
    echo "Generated: $(date)"
    echo "Workspace: $ROOT"
    echo "============================================================"
    echo
    echo "macOS"
    sw_vers 2>/dev/null || true
    echo
    echo "Compiler"
    clang --version | head -n 5 || true
    clang++ --version | head -n 5 || true
    echo
    echo "CMake"
    cmake --version | head -n 5 || true
    echo
    echo "Ninja"
    ninja --version || true
    echo
    echo "Homebrew"
    brew --version | head -n 5 || true
    echo
    echo "Brew package versions"
    for p in cmake ninja ccache pkg-config git subversion qt python@3.12 cairo freetype fontconfig harfbuzz hunspell icu4c jpeg-turbo libpng libtiff little-cms2 libxml2 boost poppler podofo librevenge libcdr libfreehand libpagemaker libmspub libvisio; do
      brew list --versions "$p" 2>/dev/null || echo "MISSING: $p"
    done
    echo
    echo "Scribus source version"
    if [ -f "$SRC/CMakeLists.txt" ]; then
      grep -n "VERSION_MAJOR\|VERSION_MINOR\|VERSION_PATCH" "$SRC/CMakeLists.txt" | head -n 10 || true
    else
      echo "No source extracted yet."
    fi
  } | tee "$out"
  echo "Version lock saved to: $out"
}

audit() {
  say "Writing workspace audit"
  local out="$LOGS/current-workspace-audit.txt"
  mkdir -p "$LOGS"
  {
    echo "CURRENT SCRIBUS-V2 WORKSPACE AUDIT"
    echo "Generated: $(date)"
    echo "Workspace: $ROOT"
    echo "============================================================"
    echo
    echo "Top-level files:"
    find "$ROOT" -maxdepth 1 -print | sort
    echo
    echo "Folder sizes:"
    for d in downloads src build install logs _archive; do
      if [ -d "$ROOT/$d" ]; then
        du -sh "$ROOT/$d" || true
      else
        echo "missing: $d"
      fi
    done
    echo
    echo "Source version:"
    if [ -f "$SRC/CMakeLists.txt" ]; then
      grep -n "VERSION_MAJOR\|VERSION_MINOR\|VERSION_PATCH" "$SRC/CMakeLists.txt" | head -n 10 || true
    else
      echo "No source found."
    fi
    echo
    echo "Patch status:"
    if [ -f "$SRC/scribus/plugins/import/CMakeLists.txt" ]; then
      grep -n -i "pdf" "$SRC/scribus/plugins/import/CMakeLists.txt" || true
    else
      echo "No import CMakeLists found."
    fi
    echo
    echo "Installed app/binary:"
    find "$INSTALL_DIR" -maxdepth 6 \( -iname "Scribus*.app" -o -iname "scribus" \) 2>/dev/null || true
    echo
    echo "Logs/reports:"
    find "$LOGS" -maxdepth 1 -type f -print | sort 2>/dev/null || true
  } | tee "$out"
  echo "Audit saved to: $out"
}

tidy() {
  say "Archiving old temporary files"
  local stamp archive
  stamp="$(date +%Y%m%d-%H%M%S)"
  archive="$ROOT/_archive/$stamp"
  mkdir -p "$archive"

  moved=0
  for f in check-env-mac.sh setup-stock-mac.sh disable-pdf-importer-mac.sh make-prod-mac-kit.sh env-report.txt; do
    if [ -e "$ROOT/$f" ]; then
      mv "$ROOT/$f" "$archive/"
      echo "Archived: $f"
      moved=1
    fi
  done

  for f in "$LOGS"/configure-stock-mac.log "$LOGS"/build-stock-mac.log "$LOGS"/install-stock-mac.log "$LOGS"/build-stock-mac-no-pdf.log "$LOGS"/install-stock-mac-no-pdf.log; do
    if [ -e "$f" ]; then
      mv "$f" "$archive/"
      echo "Archived: ${f#$ROOT/}"
      moved=1
    fi
  done

  if [ "$moved" -eq 0 ]; then
    echo "Nothing old to archive."
    rmdir "$archive" 2>/dev/null || true
  else
    echo "Old files moved to: $archive"
  fi
}

clean_generated() {
  say "Cleaning generated build outputs"
  echo "This removes build/, install/, and logs/*.log. It keeps downloads/ and src/."
  rm -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$LOGS"
  rm -f "$LOGS"/*.log
  echo "Clean complete."
}

open_app() {
  say "Opening installed Scribus app"
  local app
  app="$(find "$INSTALL_DIR" -maxdepth 6 -iname "Scribus*.app" -print -quit 2>/dev/null || true)"
  if [ -n "$app" ]; then
    echo "Opening: $app"
    open "$app"
  else
    echo "No Scribus .app found under: $INSTALL_DIR"
    find "$INSTALL_DIR" -maxdepth 6 \( -iname "Scribus*.app" -o -iname "scribus" \) 2>/dev/null || true
    exit 1
  fi
}

cmd="${1:-setup}"
case "$cmd" in
  setup) setup_workspace; doctor; lock_versions; audit ;;
  build) build_normal; doctor; audit ;;
  rebuild-fresh) build_fresh; doctor; audit ;;
  doctor) doctor ;;
  lock) lock_versions ;;
  audit) audit ;;
  tidy) setup_workspace; tidy; audit ;;
  clean) clean_generated ;;
  open) open_app ;;
  all) setup_workspace; build_normal; doctor; lock_versions; audit ;;
  help|-h|--help) usage ;;
  *) echo "Unknown command: $cmd"; usage; exit 1 ;;
esac
