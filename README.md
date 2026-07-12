# Scribus 1.7.2 Plugin Development Workspace

This project is for developing a C++ plugin for Scribus 1.7.2.

The current test plugin is `codewindow`.

## Current plugin behavior

Inside Scribus:

```text
Extras -> Code Window...
```

The plugin opens a floating/dockable window. The window has a **Paste** button. Clicking **Paste** creates a text frame in the current document and inserts pre-entered text into that frame.

## Repository rule

The plugin source of truth is:

```text
plugin/codewindow/
```

Generated Scribus source/build/install folders are not committed:

```text
downloads/
src/
build/
install/
logs/
_archive/
```

## Platform workflows

- [macOS development build](README-mac.md): daily ARM64 plugin development and local testing.
- [Windows production build](README-windows.md): pinned MSVC x64 build, deployment, and reproducibility reports.

The source patches and dependency layouts are platform-specific. Do not reuse the macOS Poppler workaround as a substitute for the Windows patch set.

## macOS development workflow

Use macOS for daily development and first testing.

```bash
cd ~/Desktop/development/scribus-v2
./scripts/mac-build-codewindow.sh
open install/Scribus1.7.2.app
```

If the full local Scribus build needs to be recreated:

```bash
./scribus-mac-prod.sh rebuild-fresh
./scripts/mac-build-codewindow.sh
```

## Sync plugin into Scribus source

```bash
./scripts/sync-codewindow-plugin.sh
```

For the macOS workflow only, this copies:

```text
plugin/codewindow/ -> src/scribus/plugins/tools/codewindow/
```

and ensures Scribus' tools CMake file contains:

```cmake
add_subdirectory(codewindow)
```

## Windows production workflow

Windows builds are separate from macOS builds and are driven by `build-windows.cmd` plus `scripts/windows/scribus-win-prod.ps1`.

Quickstart on Windows:

```bat
build-windows.cmd all
```

See [README-windows.md](README-windows.md) for prerequisites, exact versions, subcommands, deployment, and troubleshooting.

## Git setup

After creating a public GitHub repository:

```bash
git init
git add .
git commit -m "Initial Scribus 1.7.2 plugin workspace"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

## Important

Do not commit generated folders. They are intentionally ignored by `.gitignore`.
