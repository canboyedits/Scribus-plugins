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

This copies:

```text
plugin/codewindow/ -> src/scribus/plugins/tools/codewindow/
```

and ensures Scribus' tools CMake file contains:

```cmake
add_subdirectory(codewindow)
```

## Windows plan

Windows builds are separate from macOS builds. The Windows plugin must be compiled on Windows with MSVC, Windows Qt, and the Scribus 1.7.2 Windows build environment.

Planned workflow:

```text
Mac:
  edit plugin code
  build/test plugin in local Scribus
  git commit
  git push

GitHub:
  later: Windows build workflow checks that plugin builds

Windows PC:
  git pull
  build Windows version
  install/copy plugin DLL into Scribus 1.7.2 Windows
  manually test in Scribus
```

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

