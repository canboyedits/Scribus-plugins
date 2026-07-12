[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('setup','deps','build','rebuild-fresh','install','deploy','doctor','lock','audit','tidy','clean','open','all','help')]
    [string]$Command = 'help',
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $Root = if ($env:SCRIBUS_V2_ROOT) { $env:SCRIBUS_V2_ROOT } else { 'C:\Developer\scribus-v2' }
}
$Root = [IO.Path]::GetFullPath($Root)
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Downloads = Join-Path $Root 'downloads'
$Source = Join-Path $Root 'src'
$Deps = Join-Path $Root 'deps'
$Build = Join-Path $Root 'build-stock-v5'
$Install = Join-Path $Root 'install-stock-v5'
$Logs = Join-Path $Root 'logs'
$Tools = Join-Path $Root 'tools'
$PkgConfig = Join-Path $Root 'pkgconfig'
$ArchiveDir = Join-Path $Root '_archive'
$SourceArchive = Join-Path $Downloads 'scribus-1.7.2.7z'
$DepsArchive = Join-Path $Downloads 'scribus-1.7.x-libs-msvc-20260109.7z'
$SourceUrl = 'https://sourceforge.net/projects/scribus/files/scribus-devel/1.7.2/scribus-1.7.2.7z/download'
$DepsUrl = 'https://sourceforge.net/projects/scribus/files/scribus-libs/scribus-1.7.x/scribus-1.7.x-libs-msvc-20260109.7z/download'
$SourceSha256 = '867621139E21EC96006A51CAF54DAE39057FB8903434DE4CCC88E61DC67E5024'
$DepsSha256 = 'D2A7C7E87CF459AA9748D9556D727C92A01F4E9C41B3765003D204F00046BA29'
$QtRoot = if ($env:QT_ROOT) { $env:QT_ROOT } else { 'C:\Developer\Qt\6.8.3\msvc2022_64' }
$WindowsSdkVersion = '10.0.26100.0'
$ExpectedPython = '3.12.10'

$DependencyVersions = [ordered]@{
    'boost'='1.75.0'; 'cairo'='1.18.4'; 'freetype'='2.13.3'; 'harfbuzz'='11.2.1'
    'hunspell'='1.7.2'; 'icu'='76.1'; 'lcms2'='2.17'; 'libcdr'='0.1.8'
    'libfreehand'='0.1.2'; 'libiconv'='1.17'; 'libjpeg'='9f'; 'liblzma'='5.8.2'
    'libmspub'='0.1.4'; 'libpagemaker'='0.0.4'; 'libpng'='1.6.53'; 'libqxp'='0.0.2'
    'librevenge'='0.0.5'; 'libtiff'='4.7.1'; 'libvisio'='0.1.10'; 'libxml2'='2.15.1'
    'libzmf'='0.0.2'; 'openssl'='3.5.4'; 'pixman'='0.46.4'; 'podofo'='1.0.3'
    'poppler'='26.01.0'; 'poppler-data'='0.4.12'; 'python-kit'='3.13.11'; 'zlib'='1.3.1'
}

function Say([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Fail([string]$Message) { throw $Message }
function Ensure-Directories { @($Root,$Downloads,$Logs,$Tools,$PkgConfig) | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null } }
function Need-Command([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) { Fail "Required command '$Name' was not found in PATH." }
    return $command.Source
}
function Run([string]$File, [string[]]$Arguments) {
    Write-Host "> $File $($Arguments -join ' ')"
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { Fail "Command failed with exit code ${LASTEXITCODE}: $File" }
}
function Get-SevenZip {
    $candidate = 'C:\Program Files\7-Zip\7z.exe'
    if (Test-Path $candidate) { return $candidate }
    return Need-Command '7z.exe'
}
function Import-MsvcEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { Fail 'vswhere.exe is missing; install VS 2022 Build Tools with C++ tools.' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { Fail 'VS 2022 C++ x64 tools were not found.' }
    $devcmd = Join-Path $vs 'Common7\Tools\VsDevCmd.bat'
    cmd.exe /d /s /c "`"$devcmd`" -arch=x64 -host_arch=x64 >nul && set" | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
    }
    if ($LASTEXITCODE -ne 0) { Fail 'Failed to load the VS 2022 x64 build environment.' }
}
function Resolve-Python {
    $candidates = @()
    if ($env:SCRIBUS_PYTHON) { $candidates += $env:SCRIBUS_PYTHON }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) { $candidates += $python.Source }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        $version = (& $candidate --version 2>&1).ToString().Replace('Python ','').Trim()
        if ($version -eq $ExpectedPython) { return $candidate }
    }
    Fail "Python $ExpectedPython was not found. Install that exact x64 version or set SCRIBUS_PYTHON."
}
function Download-IfMissing([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) { Write-Host "Using existing $Destination"; return }
    Say "Downloading $(Split-Path $Destination -Leaf)"
    Invoke-WebRequest -Uri $Url -OutFile $Destination
}
function Verify-FileHash([string]$Path, [string]$Expected) {
    $actual = (Get-FileHash $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { Fail "SHA-256 mismatch for $Path. Expected $Expected, got $actual." }
}
function Get-DepPath([string]$Name, [string]$Version) { Join-Path $Deps "$Name-$Version" }
function Verify-Dependencies {
    foreach ($entry in $DependencyVersions.GetEnumerator()) {
        $folderName = if ($entry.Key -eq 'python-kit') { "python-$($entry.Value)" } else { "$($entry.Key)-$($entry.Value)" }
        if (-not (Test-Path (Join-Path $Deps $folderName))) { Fail "Missing dependency folder: $folderName" }
    }
    $requiredFiles = @(
        'cairo-1.18.4\lib\x64-v143\cairo2.lib','freetype-2.13.3\lib\x64-v143\freetype.lib',
        'harfbuzz-11.2.1\lib\x64-v143\harfbuzz.lib','hunspell-1.7.2\lib\x64-v143\libhunspell_static.lib',
        'icu-76.1\lib\x64-v143\icuuc.lib','lcms2-2.17\lib\x64-v143\lcms2_static.lib',
        'libjpeg-9f\lib\x64-v143\libjpeg9f.lib','libpng-1.6.53\lib\x64-v143\libpng16.lib',
        'libtiff-4.7.1\lib\x64-v143\libtiff5.lib','libxml2-2.15.1\lib\x64-v143\libxml2.lib',
        'poppler-26.01.0\lib\x64-v143\poppler_static.lib','zlib-1.3.1\lib\x64-v143\zlib1.lib'
    )
    foreach ($relative in $requiredFiles) { if (-not (Test-Path (Join-Path $Deps $relative))) { Fail "Dependency kit is extracted but not built: $relative" } }
}
function Install-DependencyKit {
    if (Test-Path $Deps) { return }
    Download-IfMissing $DepsUrl $DepsArchive
    Verify-FileHash $DepsArchive $DepsSha256
    $temp = Join-Path $Root '_tmp\deps-extract'
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    Run (Get-SevenZip) @('x','-y',"-o$temp",$DepsArchive)
    $payload = Get-ChildItem $temp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'scribus-libs-msvc2022.sln') } | Select-Object -First 1
    if (-not $payload) { Fail 'Could not locate the extracted MSVC dependency-kit root.' }
    Move-Item $payload.FullName $Deps
    Import-MsvcEnvironment
    Run 'msbuild.exe' @(
        (Join-Path $Deps 'scribus-libs-msvc2022.sln'),
        '/m:1', '/t:Build', '/p:Configuration=Release', '/p:Platform=x64',
        "/p:WindowsTargetPlatformVersion=$WindowsSdkVersion"
    )
}
function Initialize-PkgConfig([string]$Python) {
    Copy-Item (Join-Path $PSScriptRoot 'fake-pkg-config.py') (Join-Path $Tools 'fake-pkg-config.py') -Force
    Set-Content (Join-Path $Tools 'fake-pkg-config.cmd') "@echo off`r`n`"$Python`" `"$Tools\fake-pkg-config.py`" %*`r`n" -Encoding Ascii
    $specs = [ordered]@{
        'cairo'=@('1.18.4','cairo-1.18.4','cairo2','include'); 'libcairo'=@('1.18.4','cairo-1.18.4','cairo2','include')
        'harfbuzz'=@('11.2.1','harfbuzz-11.2.1','harfbuzz','include -I{root}/deps/harfbuzz-11.2.1/include/harfbuzz')
        'harfbuzz-subset'=@('11.2.1','harfbuzz-11.2.1','harfbuzz','include -I{root}/deps/harfbuzz-11.2.1/include/harfbuzz')
        'harfbuzz-icu'=@('11.2.1','harfbuzz-11.2.1','harfbuzz','include -I{root}/deps/harfbuzz-11.2.1/include/harfbuzz -I{root}/deps/icu-76.1/include')
        'hunspell'=@('1.7.2','hunspell-1.7.2','libhunspell_static','include'); 'libhunspell'=@('1.7.2','hunspell-1.7.2','libhunspell_static','include')
        'icu-uc'=@('76.1','icu-76.1','icuuc -licudt','include'); 'icu-i18n'=@('76.1','icu-76.1','icuin -licuuc -licudt','include')
        'podofo'=@('1.0.3','podofo-1.0.3','podofo','include'); 'libpodofo'=@('1.0.3','podofo-1.0.3','podofo','include')
        'poppler'=@('26.01.0','poppler-26.01.0','poppler_static','include -I{root}/deps/poppler-26.01.0/include/poppler -I{root}/deps/poppler-26.01.0/include/poppler/cpp')
        'libpoppler'=@('26.01.0','poppler-26.01.0','poppler_static','include -I{root}/deps/poppler-26.01.0/include/poppler -I{root}/deps/poppler-26.01.0/include/poppler/cpp')
        'poppler-cpp'=@('26.01.0','poppler-26.01.0','poppler_static','include -I{root}/deps/poppler-26.01.0/include/poppler -I{root}/deps/poppler-26.01.0/include/poppler/cpp')
        'libpoppler-cpp'=@('26.01.0','poppler-26.01.0','poppler_static','include -I{root}/deps/poppler-26.01.0/include/poppler -I{root}/deps/poppler-26.01.0/include/poppler/cpp')
    }
    $unixRoot = $Root.Replace('\','/')
    foreach ($spec in $specs.GetEnumerator()) {
        $version,$folder,$libs,$includes = $spec.Value
        $includeFlags = if ($includes -eq 'include') { "-I$unixRoot/deps/$folder/include" } else { "-I$unixRoot/deps/$folder/" + $includes.Replace('{root}',$unixRoot) }
        $libDir = if ($folder -like 'podofo*' -or $folder -like 'poppler*' -or $folder -like 'cairo*' -or $folder -like 'harfbuzz*' -or $folder -like 'hunspell*' -or $folder -like 'icu*') { "$unixRoot/deps/$folder/lib/x64-v143" } else { "$unixRoot/deps/$folder/lib/x64-v143" }
        $libFlags = ($libs -split ' ' | ForEach-Object { if ($_ -like '-l*') { $_ } else { "-l$_" } }) -join ' '
        Set-Content (Join-Path $PkgConfig "$($spec.Key).pc") "Name: $($spec.Key)`nVersion: $version`nLibs: -L$libDir $libFlags`nCflags: $includeFlags`n" -Encoding Ascii
    }
    $env:SCRIBUS_PKGCONFIG_DIR = $PkgConfig
}
function Sync-Plugin {
    $from = Join-Path $RepoRoot 'plugin\codewindow'
    $to = Join-Path $Source 'scribus\plugins\codewindow'
    if (-not (Test-Path (Join-Path $from 'CMakeLists.txt'))) { Fail "Canonical plugin source missing: $from" }
    New-Item -ItemType Directory -Force -Path $to | Out-Null
    Copy-Item (Join-Path $from '*') $to -Recurse -Force
    $stale = Join-Path $Source 'scribus\plugins\tools\codewindow'
    if (Test-Path $stale) { Fail "Stale duplicate plugin directory exists: $stale. Use rebuild-fresh so only the canonical plugin is present." }
}
function Apply-Patches {
    $git = Need-Command 'git.exe'
    Get-ChildItem (Join-Path $RepoRoot 'patches\windows\*.patch') | Sort-Object Name | ForEach-Object {
        & $git -C $Source apply --check $_.FullName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Run $git @('-C',$Source,'apply','--whitespace=nowarn',$_.FullName)
        } else {
            & $git -C $Source apply --reverse --check $_.FullName 2>$null
            if ($LASTEXITCODE -ne 0) { Fail "Patch cannot be applied or recognized as already applied: $($_.Name)" }
            Write-Host "Already applied: $($_.Name)"
        }
    }
}
function Extract-Source([switch]$Fresh) {
    Download-IfMissing $SourceUrl $SourceArchive
    Verify-FileHash $SourceArchive $SourceSha256
    if ($Fresh -and (Test-Path $Source)) { Remove-Item $Source -Recurse -Force }
    if (-not (Test-Path (Join-Path $Source 'CMakeLists.txt'))) {
        $temp = Join-Path $Root '_tmp\source-extract'
        if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $temp | Out-Null
        Run (Get-SevenZip) @('x','-y',"-o$temp",$SourceArchive)
        $payload = Get-ChildItem $temp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'CMakeLists.txt') } | Select-Object -First 1
        if (-not $payload) { Fail 'Could not locate extracted Scribus source.' }
        Move-Item $payload.FullName $Source
    }
}
function Configure-Build {
    Import-MsvcEnvironment
    $python = Resolve-Python
    Initialize-PkgConfig $python
    $d = { param($name,$version) (Get-DepPath $name $version) }
    $args = @('-S',$Source,'-B',$Build,'-G','Ninja',
        '-DCMAKE_BUILD_TYPE=Release',"-DCMAKE_INSTALL_PREFIX=$Install", "-DCMAKE_PREFIX_PATH=$QtRoot;$Deps;$(Get-DepPath boost '1.75.0')",
        "-DQT_PREFIX=$QtRoot","-DPython3_EXECUTABLE=$python","-DPKG_CONFIG_EXECUTABLE=$Tools\fake-pkg-config.cmd",
        '-DLIBPODOFO_SHARED:BOOL=1',"-DOPENSSL_ROOT_DIR=$(Get-DepPath openssl '3.5.4')", "-DOPENSSL_INCLUDE_DIR=$(Get-DepPath openssl '3.5.4')\include",
        "-DOPENSSL_CRYPTO_LIBRARY=$(Get-DepPath openssl '3.5.4')\lib\x64\libcrypto.lib", "-DOPENSSL_SSL_LIBRARY=$(Get-DepPath openssl '3.5.4')\lib\x64\libssl.lib",
        "-DZLIB_INCLUDE_DIR=$(Get-DepPath zlib '1.3.1')\include", "-DZLIB_LIBRARY=$(Get-DepPath zlib '1.3.1')\lib\x64-v143\zlib1.lib",
        "-DJPEG_INCLUDE_DIR=$(Get-DepPath libjpeg '9f')\include", "-DJPEG_LIBRARY=$(Get-DepPath libjpeg '9f')\lib\x64-v143\libjpeg9f.lib",
        "-DPNG_PNG_INCLUDE_DIR=$(Get-DepPath libpng '1.6.53')\include", "-DPNG_LIBRARY=$(Get-DepPath libpng '1.6.53')\lib\x64-v143\libpng16.lib",
        "-DTIFF_INCLUDE_DIR=$(Get-DepPath libtiff '4.7.1')\include", "-DTIFF_LIBRARY=$(Get-DepPath libtiff '4.7.1')\lib\x64-v143\libtiff5.lib",
        "-DLCMS2_INCLUDE_DIR=$(Get-DepPath lcms2 '2.17')\include", "-DLCMS2_LIBRARY=$(Get-DepPath lcms2 '2.17')\lib\x64-v143\lcms2_static.lib",
        "-DFREETYPE_INCLUDE_DIRS=$(Get-DepPath freetype '2.13.3')\include", "-DFREETYPE_LIBRARY=$(Get-DepPath freetype '2.13.3')\lib\x64-v143\freetype.lib",
        "-DLIBXML2_INCLUDE_DIR=$(Get-DepPath libxml2 '2.15.1')\include", "-DLIBXML2_LIBRARY=$(Get-DepPath libxml2 '2.15.1')\lib\x64-v143\libxml2.lib",
        "-DHUNSPELL_INCLUDE_DIR=$(Get-DepPath hunspell '1.7.2')\include", "-DHUNSPELL_LIBRARY=$(Get-DepPath hunspell '1.7.2')\lib\x64-v143\libhunspell_static.lib",
        "-Dpoppler_INCLUDE_DIR=$(Get-DepPath poppler '26.01.0')\include\poppler", "-Dpoppler_LIBRARY=$(Get-DepPath poppler '26.01.0')\lib\x64-v143\poppler_static.lib",
        '-DWANT_PCH=OFF','-DWANT_CCACHE=OFF','-DWANT_GRAPHICSMAGICK=OFF','-DWANT_NOOSG=ON','-DWANT_HUNSPELL_PLUGIN=OFF','-DWANT_RTF_PLUGIN=OFF',
        "-DCMAKE_SYSTEM_VERSION=$WindowsSdkVersion","-DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=$WindowsSdkVersion",
        "-DCMAKE_C_FLAGS=/I$($Deps.Replace('\','/'))/icu-76.1/include",
        "-DCMAKE_CXX_FLAGS=/EHsc /Zc:__cplusplus /I$($Deps.Replace('\','/'))/icu-76.1/include",
        "-DCMAKE_CXX_FLAGS_RELEASE=/O2 /Ob2 /DNDEBUG /EHsc /Zc:__cplusplus /I$($Deps.Replace('\','/'))/icu-76.1/include")
    Run 'cmake.exe' $args
    Run 'cmake.exe' @('--build',$Build,'--parallel','1')
}
function Invoke-Setup { Ensure-Directories; Write-Host "Workspace ready: $Root" }
function Invoke-Deps {
    Ensure-Directories; Need-Command 'cmake.exe' | Out-Null; Need-Command 'ninja.exe' | Out-Null; Get-SevenZip | Out-Null
    if (-not (Test-Path $QtRoot)) { Fail "Qt 6.8.3 MSVC root missing: $QtRoot" }
    $null = Resolve-Python; Import-MsvcEnvironment
    if (-not (Test-Path $Deps)) { Install-DependencyKit }
    Verify-Dependencies
    Write-Host 'Dependency verification passed.'
}
function Invoke-Build([switch]$Fresh) { Invoke-Deps; Extract-Source -Fresh:$Fresh; Apply-Patches; Sync-Plugin; Configure-Build }
function Invoke-Install { Import-MsvcEnvironment; Run 'cmake.exe' @('--install',$Build) }
function Invoke-Deploy {
    $exe = Join-Path $Install 'scribus.exe'; if (-not (Test-Path $exe)) { Fail "Installed executable missing: $exe" }
    $plugin = Join-Path $Install 'plugins\codewindow.dll'; if (-not (Test-Path $plugin)) { Fail "Installed plugin missing: $plugin" }
    Run (Join-Path $QtRoot 'bin\windeployqt.exe') @('--release','--compiler-runtime',$exe)
    $dlls = @('cairo-1.18.4\cairo2.dll','libxml2-2.15.1\libxml2.dll','zlib-1.3.1\zlib1.dll','freetype-2.13.3\freetype.dll','harfbuzz-11.2.1\harfbuzz.dll','libpng-1.6.53\libpng16.dll','libjpeg-9f\libjpeg9f.dll','libtiff-4.7.1\libtiff5.dll','liblzma-5.8.2\liblzma.dll','libiconv-1.17\iconv.dll','icu-76.1\icudt76.dll','icu-76.1\icuin76.dll','icu-76.1\icuuc76.dll')
    foreach ($item in $dlls) { $folder,$name = $item -split '\\',2; $sourceDll = Join-Path (Join-Path $Deps $folder) "lib\x64-v143\$name"; if (-not (Test-Path $sourceDll)) { Fail "Runtime DLL missing: $sourceDll" }; Copy-Item $sourceDll $Install -Force }
    Import-MsvcEnvironment
    $dumpbin = Need-Command 'dumpbin.exe'; $missing = @()
    Get-ChildItem $Install -Recurse -File -Include *.exe,*.dll | ForEach-Object { $output = & $dumpbin /DEPENDENTS $_.FullName 2>$null; foreach ($line in $output) { if ($line -match '^\s+([^\s]+\.dll)\s*$') { $dll = $matches[1]; if ($dll -notmatch '^(api-ms-|ext-ms-|kernel32|user32|gdi32|advapi32|shell32|ole32|oleaut32|comdlg32|combase|ntdll|ucrtbase|vcruntime|msvcp|ws2_32|winspool|shlwapi|version|dwmapi|uxtheme|bcrypt|crypt32|secur32|imm32|setupapi|winmm|mpr|userenv|d3d|dxgi|dxguid|rpcrt4|normaliz)' -and -not (Get-ChildItem $Install -Recurse -Filter $dll -ErrorAction SilentlyContinue)) { $missing += "$($_.Name): $dll" } } } }
    if ($missing) { Fail "Unresolved non-system imports:`n$($missing | Sort-Object -Unique | Out-String)" }
}
function Invoke-Doctor {
    Ensure-Directories; $out = Join-Path $Logs 'win-env-report.txt'; $lines = @("SCRIBUS WINDOWS ENVIRONMENT REPORT","Generated: $(Get-Date -Format o)","Root: $Root","Qt: $QtRoot","CMake: $(& cmake --version | Select-Object -First 1)","Ninja: $(& ninja --version)","Python: $(& (Resolve-Python) --version)")
    Import-MsvcEnvironment; $lines += "MSVC: $(& cl 2>&1 | Select-Object -First 1)"; $lines | Set-Content $out; $lines | Write-Output
}
function Invoke-Lock {
    Ensure-Directories; $out = Join-Path $Logs 'win-version-lock.txt'; $lines = @('SCRIBUS 1.7.2 WINDOWS VERSION LOCK','Qt=6.8.3','MSVC=19.44.35228','CMake=4.3.4','Ninja=1.13.2','Python=3.12.10',"WindowsSDK=$WindowsSdkVersion",'SourceArchiveSHA256='+$SourceSha256,'DepsArchiveSHA256='+$DepsSha256); foreach ($e in $DependencyVersions.GetEnumerator()) { $lines += "$($e.Key)=$($e.Value)" }; $lines | Set-Content $out; $lines | Write-Output
}
function Invoke-Audit { Ensure-Directories; $out=Join-Path $Logs 'current-workspace-audit.txt'; $lines=@("Generated: $(Get-Date -Format o)","Root: $Root"); foreach($name in 'downloads','src','deps','build-stock-v5','install-stock-v5','logs','_archive'){ $p=Join-Path $Root $name; $size=if(Test-Path $p){(Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum}else{0}; $lines += "$name`t$size bytes" }; $lines|Set-Content $out; $lines|Write-Output }
function Invoke-Tidy { Ensure-Directories; $dest=Join-Path $ArchiveDir (Get-Date -Format 'yyyyMMdd-HHmmss'); $items=@('build-stock-v1','build-stock-v2','build-stock-v3','build-stock-v4','install-stock-v1','install-stock-v2','install-stock-v3','install-stock-v4','_tmp') + (Get-ChildItem $Root -Directory -Filter '_backup-*' -ErrorAction SilentlyContinue|ForEach-Object Name); foreach($name in $items|Select-Object -Unique){$p=Join-Path $Root $name;if(Test-Path $p){New-Item -ItemType Directory -Force $dest|Out-Null;Move-Item $p $dest;Write-Host "Archived $p"}} }
function Invoke-Clean { foreach($p in @($Build,$Install)){if(Test-Path $p){Remove-Item $p -Recurse -Force}}; New-Item -ItemType Directory -Force -Path @($Build,$Install)|Out-Null }
function Invoke-Open { $exe=Join-Path $Install 'scribus.exe';if(-not(Test-Path $exe)){Fail "Missing $exe"};Start-Process $exe }
function Usage { Write-Host 'build-windows.cmd <setup|deps|build|rebuild-fresh|install|deploy|doctor|lock|audit|tidy|clean|open|all> [-Root PATH]' }

switch ($Command) {
    'setup' { Invoke-Setup }; 'deps' { Invoke-Deps }; 'build' { Invoke-Build }; 'rebuild-fresh' { Invoke-Build -Fresh }
    'install' { Invoke-Install }; 'deploy' { Invoke-Deploy }; 'doctor' { Invoke-Doctor }; 'lock' { Invoke-Lock }
    'audit' { Invoke-Audit }; 'tidy' { Invoke-Tidy }; 'clean' { Invoke-Clean }; 'open' { Invoke-Open }
    'all' { Invoke-Setup; Invoke-Deps; Invoke-Build; Invoke-Install; Invoke-Deploy; Invoke-Doctor; Invoke-Lock; Invoke-Audit }
    default { Usage }
}
