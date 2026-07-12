# Scribus 1.7.2 Windows x64 Production Build

This workflow reproduces the tested Windows build of Scribus 1.7.2 with the custom `codewindow` plugin. It is separate from the macOS development build documented in [README-mac.md](README-mac.md).

## Tested target

- Windows 10 x64 or newer
- Scribus 1.7.2
- Qt 6.8.3 `msvc2022_64`
- MSVC 2022 x64/v143
- `codewindow` loaded from `plugins\codewindow.dll`
- PDF importer, Hunspell plugin, RTF importer, 3D extension, GraphicsMagick, PCH, and ccache disabled
- PoDoFo/OpenSSL-dependent PDF-in-AI support remains disabled, matching the tested build

## Prerequisites

Install these before running the script:

1. Visual Studio 2022 Build Tools with:
   - Desktop development with C++
   - MSVC v143 x64/x86 build tools
   - Windows 10/11 SDK 10.0.26100.0
2. Qt 6.8.3, MSVC 2022 64-bit, at `C:\Developer\Qt\6.8.3\msvc2022_64`.
3. Python 3.12.10 x64. It must be `python.exe` in `PATH`, or set `SCRIBUS_PYTHON`.
4. CMake 4.3.4.
5. Ninja 1.13.2.
6. Git for Windows.
7. 7-Zip, normally at `C:\Program Files\7-Zip\7z.exe`.

Do not substitute the dependency kit’s Python 3.13.11 for the pinned build Python. The successful build linked Python 3.12.10.

## Quickstart

Open a normal Command Prompt or PowerShell in the cloned repository:

```bat
build-windows.cmd all
```

The default workspace is:

```text
C:\Developer\scribus-v2
```

Override it with either:

```bat
build-windows.cmd all -Root D:\Build\scribus-v2
```

or:

```bat
set SCRIBUS_V2_ROOT=D:\Build\scribus-v2
build-windows.cmd all
```

The final executable is:

```text
C:\Developer\scribus-v2\install-stock-v5\scribus.exe
```

## Commands

| Command | Purpose |
|---|---|
| `setup` | Create the workspace directories. |
| `deps` | Verify exact tools/dependencies; download, verify, extract, and build the official MSVC dependency kit when absent. |
| `build` | Download/extract source if needed, apply Windows patches, sync the canonical plugin, configure, and build. |
| `rebuild-fresh` | Re-extract pristine source and perform the same patched build. |
| `install` | Run `cmake --install` into `install-stock-v5`. |
| `deploy` | Run `windeployqt`, copy the pinned x64-v143 DLLs, and audit imports with `dumpbin /DEPENDENTS`. |
| `doctor` | Write `logs\win-env-report.txt`. |
| `lock` | Write the exact reproducibility contract to `logs\win-version-lock.txt`. |
| `audit` | Write workspace paths and sizes to `logs\current-workspace-audit.txt`. |
| `tidy` | Move v1-v4 builds, `_tmp`, and `_backup-*` into timestamped `_archive` storage. It does not delete them. |
| `clean` | Remove only `build-stock-v5` and `install-stock-v5`. Downloads, source, and dependencies remain. |
| `open` | Launch the installed `scribus.exe`. |
| `all` | `setup + deps + build + install + deploy + doctor + lock + audit`. |

## Version lock

| Component | Version |
|---|---:|
| Scribus | 1.7.2 |
| Qt | 6.8.3 |
| MSVC compiler | 19.44.35228 |
| MSVC tool directory | 14.44.35207 |
| Windows SDK | 10.0.26100.0 |
| CMake | 4.3.4 |
| Ninja | 1.13.2 |
| Python used by Scribus | 3.12.10 |
| Boost | 1.75.0 |
| Cairo | 1.18.4 |
| FreeType | 2.13.3 |
| HarfBuzz | 11.2.1 |
| Hunspell | 1.7.2 |
| ICU | 76.1 |
| Little CMS 2 | 2.17 |
| libcdr | 0.1.8 |
| libfreehand | 0.1.2 |
| libiconv | 1.17 |
| libjpeg | 9f |
| liblzma | 5.8.2 |
| libmspub | 0.1.4 |
| libpagemaker | 0.0.4 |
| libpng | 1.6.53 |
| libqxp | 0.0.2 |
| librevenge | 0.0.5 |
| libtiff | 4.7.1 |
| libvisio | 0.1.10 |
| libxml2 | 2.15.1 |
| libzmf | 0.0.2 |
| OpenSSL | 3.5.4 |
| Pixman | 0.46.4 |
| PoDoFo | 1.0.3 |
| Poppler | 26.01.0 |
| Poppler data | 0.4.12 |
| zlib | 1.3.1 |

The dependency kit is:

```text
https://sourceforge.net/projects/scribus/files/scribus-libs/scribus-1.7.x/scribus-1.7.x-libs-msvc-20260109.7z/download
SHA-256: D2A7C7E87CF459AA9748D9556D727C92A01F4E9C41B3765003D204F00046BA29
```

## Source and patches

The source archive comes from:

```text
https://sourceforge.net/projects/scribus/files/scribus-devel/1.7.2/scribus-1.7.2.7z/download
SHA-256: 867621139E21EC96006A51CAF54DAE39057FB8903434DE4CCC88E61DC67E5024
```

The script applies every file in `patches\windows` using `git apply`. Patching is idempotent: an already-applied patch is recognized through a reverse check.

The only plugin source of truth is:

```text
plugin\codewindow\
```

It is copied to:

```text
src\scribus\plugins\codewindow\
```

The Windows workflow does not create the macOS generated location at `src\scribus\plugins\tools\codewindow`.

## Deployment

Deployment runs:

```powershell
& 'C:\Developer\Qt\6.8.3\msvc2022_64\bin\windeployqt.exe' `
  --release --compiler-runtime `
  'C:\Developer\scribus-v2\install-stock-v5\scribus.exe'
```

It then copies these Release x64-v143 DLLs beside `scribus.exe`:

```text
cairo2.dll
libxml2.dll
zlib1.dll
freetype.dll
harfbuzz.dll
libpng16.dll
libjpeg9f.dll
libtiff5.dll
liblzma.dll
iconv.dll
icudt76.dll
icuin76.dll
icuuc76.dll
```

The Microsoft Visual C++ 2022 x64 Redistributable is required on the destination machine.

## Verification

After `all` succeeds:

1. Confirm `install-stock-v5\scribus.exe` exists.
2. Confirm `install-stock-v5\plugins\codewindow.dll` exists.
3. Run `build-windows.cmd open`.
4. In Scribus, choose `Extras -> Code Window...`.
5. Create/open a document and verify that Paste creates a text frame.
6. Review `logs\win-env-report.txt`, `logs\win-version-lock.txt`, and `logs\current-workspace-audit.txt`.

## Troubleshooting

### `CreateFileA` cannot accept `wchar_t*`

The ZIP patch explicitly calls `CreateFileW`. Run a fresh build if the patch is missing:

```bat
build-windows.cmd rebuild-fresh
```

### `xy2Deg` is undefined

The Cairo painter must include `util_math.h`. This is covered by patch 003.

### `Qt6EntryPoint.lib` cannot be opened

The Windows CMake patch adds Qt Core’s linker-file directory and removes the obsolete direct qtmain link.

### Missing Qt DLL or `qwindows.dll`

Run:

```bat
build-windows.cmd deploy
```

Do not copy only the top-level Qt DLLs; `platforms`, `imageformats`, `styles`, `iconengines`, `tls`, `networkinformation`, `generic`, and translations are required.

### Missing `cairo2.dll`, `libxml2.dll`, `zlib1.dll`, or `freetype.dll`

These are not supplied by `windeployqt`. The `deploy` command copies the exact Release x64-v143 dependency DLL set.

### Wrong-architecture or Debug DLLs

Every Scribus and third-party binary must be Release x64/v143. Do not mix Win32, Debug (`*_d.dll`), v142, or v145 binaries.

### Hunspell or RTF plugin link errors

Those optional plugins intentionally remain disabled on Windows. This matches the validated production target.

### PDF importer missing

The built-in PDF importer intentionally remains disabled because Scribus 1.7.2 is not patched for the pinned Poppler 26 API.

### PoDoFo/OpenSSL support unavailable

The production recipe preserves the validated outcome: PDF-in-AI support remains disabled even though the dependency folders exist.
