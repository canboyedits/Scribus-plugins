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
