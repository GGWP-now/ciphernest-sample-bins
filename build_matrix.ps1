<#
.SYNOPSIS
    Matrix build script for all 66 victim target applications (C++ CMake, C++ MSBuild/WinUI, .NET, Rust, Go, Odin, Zig, raw PE, Python, Node.js, Electron, Tauri, Flutter, Java, cross-platform libraries/apps, LLVM LIT binary packs, scripted map/architecture/driver/runtime variants).
    Builds every target under every matrix configuration (arch × CRT × opt × security).

.DESCRIPTION
    Matrix configurations:
        x86_Debug    /MDd /Zi /Od
        x64_Debug    /MDd /Zi /Od
        x86_Release  /MT  /O2 /GS
        x64_Release  /MD  /O2 /GS /guard:cf /guard:ehcont  + linker /GUARD:CF /guard:ehcont /CETCOMPAT
        x64_SEH      /EHa /GS
        x64_LTCG     /O2  /GL                + linker /LTCG
        x64_Release_LLVM      01-calc-console only, D:\llvm-lit\llvm-project clang++
        x64_Release_GCC       01-calc-console only, GCC g++ from MSYS2/Cygwin/PATH
        x64_Release_LLVM_CL   01-calc-console only, VS 2026 clang-cl

    Output layout:
        victims/bin/{config}/   — built executables/DLLs per matrix config
        victims/build/          — intermediate CMake build trees

.PARAMETER Configs
    Comma-separated list of configs to build (default: all).
    Valid: x86_Debug, x64_Debug, x86_Release, x64_Release, x64_SEH, x64_LTCG,
           x64_Release_LLVM, x64_Release_GCC, x64_Release_LLVM_CL

.PARAMETER Targets
    Comma-separated list of target numbers (01-66) or 'all' (default: all).

.PARAMETER Clean
    Remove build directories before configuring.

.PARAMETER NoBuild
    Configure only; skip the build step.

.EXAMPLE
    .\build_matrix.ps1
    .\build_matrix.ps1 -Configs x64_Release,x64_LTCG
    .\build_matrix.ps1 -Targets 01,05,13,16,19 -Clean
#>

[CmdletBinding()]
param(
    [string]$Configs = 'all',
    [string]$Targets = 'all',
    [switch]$Clean,
    [switch]$NoBuild,
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSCommandPath
$script:EnvironmentBaseline = @{}
Get-ChildItem Env: | ForEach-Object {
    $script:EnvironmentBaseline[$_.Name] = $_.Value
}
$script:CurrentVsArch = ''

$script:VsEnvironmentVariableNames = @(
    'DevEnvDir',
    'ExtensionSdkDir',
    'Framework40Version',
    'FrameworkDir',
    'FrameworkDir64',
    'FrameworkVersion',
    'FrameworkVersion64',
    'INCLUDE',
    'LIB',
    'LIBPATH',
    'NETFXSDKDir',
    'UCRTVersion',
    'UniversalCRTSdkDir',
    'VCIDEInstallDir',
    'VCINSTALLDIR',
    'VCToolsInstallDir',
    'VCToolsRedistDir',
    'VSCMD_ARG_app_plat',
    'VSCMD_ARG_HOST_ARCH',
    'VSCMD_ARG_TGT_ARCH',
    'VSCMD_VER',
    'VSINSTALLDIR',
    'WindowsLibPath',
    'WindowsSdkBinPath',
    'WindowsSdkDir',
    'WindowsSDKLibVersion',
    'WindowsSDKVersion',
    '__DOTNET_ADD_64BIT',
    '__DOTNET_PREFERRED_BITNESS',
    '__VSCMD_PREINIT_PATH'
)

function Restore-BaselineEnvironmentForVsImport {
    $currentNames = @(Get-ChildItem Env: | ForEach-Object { $_.Name })
    foreach ($name in $currentNames) {
        if (-not $script:EnvironmentBaseline.ContainsKey($name)) {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }

    foreach ($entry in $script:EnvironmentBaseline.GetEnumerator()) {
        if ($script:VsEnvironmentVariableNames -contains $entry.Key) {
            continue
        }
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }

    foreach ($name in $script:VsEnvironmentVariableNames) {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }

    $basePath = $script:EnvironmentBaseline['PATH']
    if ($script:EnvironmentBaseline.ContainsKey('__VSCMD_PREINIT_PATH') -and -not [string]::IsNullOrWhiteSpace($script:EnvironmentBaseline['__VSCMD_PREINIT_PATH'])) {
        $basePath = $script:EnvironmentBaseline['__VSCMD_PREINIT_PATH']
    }
    if (-not [string]::IsNullOrWhiteSpace($basePath)) {
        [Environment]::SetEnvironmentVariable('PATH', $basePath, 'Process')
    }
}

function Get-NormalizedPathForCompare {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    try {
        if (Test-Path -LiteralPath $Path) {
            return ([System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)).TrimEnd('\').ToLowerInvariant()
        }
        return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\').ToLowerInvariant()
    }
    catch {
        return ($Path -replace '/', '\').TrimEnd('\').ToLowerInvariant()
    }
}

function Remove-BuildDirectorySafely {
    param([string]$BuildDir)

    if (-not (Test-Path -LiteralPath $BuildDir)) {
        return
    }

    $resolvedTarget = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $BuildDir).Path).TrimEnd('\')
    $resolvedBuildRoot = [System.IO.Path]::GetFullPath((Join-Path $script:Root 'build')).TrimEnd('\')
    if (-not $resolvedTarget.StartsWith($resolvedBuildRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove build directory outside workspace build root: $resolvedTarget"
    }

    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

function Remove-OutputDirectorySafely {
    param([string]$OutputPath)

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        return
    }

    $resolvedTarget = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $OutputPath).Path).TrimEnd('\')
    $outputRoot = if ([string]::IsNullOrWhiteSpace($OutDir)) { Join-Path $script:Root 'bin' } else { $OutDir }
    $resolvedOutputRoot = [System.IO.Path]::GetFullPath($outputRoot).TrimEnd('\')
    if (-not $resolvedTarget.StartsWith($resolvedOutputRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove output directory outside configured output root: $resolvedTarget"
    }

    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

$DefaultLlvmProjectDir = if ([string]::IsNullOrWhiteSpace($env:LLVM_PROJECT_DIR)) { 'D:\llvm-lit\llvm-project' } else { $env:LLVM_PROJECT_DIR }
$DefaultLlvmBuildDir   = if ([string]::IsNullOrWhiteSpace($env:LLVM_BUILD_DIR)) { Join-Path $DefaultLlvmProjectDir 'build\Release' } else { $env:LLVM_BUILD_DIR }
$DefaultPythonX86Root  = if ([string]::IsNullOrWhiteSpace($env:PYTHON_X86_ROOT)) { 'C:\Python310-32' } else { $env:PYTHON_X86_ROOT }
$DefaultNodeX86Root    = if ([string]::IsNullOrWhiteSpace($env:NODE_X86_ROOT)) { 'C:\node-v22.22.3-win-x86' } else { $env:NODE_X86_ROOT }
$DefaultJavaX86Root    = if ([string]::IsNullOrWhiteSpace($env:JAVA_X86_HOME)) { 'C:\Program Files (x86)\Java\latest\jre-1.8' } else { $env:JAVA_X86_HOME }
$DefaultPatchBin       = if ([string]::IsNullOrWhiteSpace($env:PATCH_BIN)) { 'C:\Program Files\Git\usr\bin' } else { $env:PATCH_BIN }
$DefaultCygwinRoot     = if ([string]::IsNullOrWhiteSpace($env:CYGWIN_ROOT)) { 'D:\cygwin' } else { $env:CYGWIN_ROOT }
$GccBinCandidates      = @(
    $env:GCC_BIN,
    $env:MSYS2_UCRT64_BIN,
    'C:\msys64\ucrt64\bin',
    (Join-Path $DefaultCygwinRoot 'bin')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$PathGxx               = Get-Command g++.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$DefaultGccBin         = $GccBinCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'g++.exe') } | Select-Object -First 1
$DefaultGccCxxCompiler = if ($DefaultGccBin) { Join-Path $DefaultGccBin 'g++.exe' } elseif ($PathGxx) { $PathGxx.Source } else { Join-Path $DefaultCygwinRoot 'bin\g++.exe' }
$DefaultGccPathPrefix  = if ($DefaultGccBin) { $DefaultGccBin } elseif ($PathGxx) { Split-Path -Parent $PathGxx.Source } else { Join-Path $DefaultCygwinRoot 'bin' }
$Vs2026RootCandidates  = @(
    "${env:ProgramFiles}\Microsoft Visual Studio\18\Community",
    "${env:ProgramFiles}\Microsoft Visual Studio\18\Professional",
    "${env:ProgramFiles}\Microsoft Visual Studio\18\Enterprise"
)
$Vs2026Root            = $Vs2026RootCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$Vs2026LlvmBin         = if ($Vs2026Root) { Join-Path $Vs2026Root 'VC\Tools\Llvm\x64\bin' } else { Join-Path $Vs2026RootCandidates[0] 'VC\Tools\Llvm\x64\bin' }

# ── Matrix definitions ──────────────────────────────────────────────────────
$Matrix = @(
    [pscustomobject]@{
        Name      = 'x86_Debug'
        Arch      = 'x86'
        Toolchain = 'msvc'
        CxxFlags  = '/MDd /Zi /Od'
        LdFlags   = ''
    },
    [pscustomobject]@{
        Name      = 'x64_Debug'
        Arch      = 'x64'
        Toolchain = 'msvc'
        CxxFlags  = '/MDd /Zi /Od'
        LdFlags   = ''
    },
    [pscustomobject]@{
        Name      = 'x86_Release'
        Arch      = 'x86'
        Toolchain = 'msvc'
        CxxFlags  = '/MT /O2 /GS'
        LdFlags   = ''
    },
    [pscustomobject]@{
        Name      = 'x64_Release'
        Arch      = 'x64'
        Toolchain = 'msvc'
        CxxFlags  = '/MD /O2 /GS /guard:cf /guard:ehcont'
        LdFlags   = '/GUARD:CF /guard:ehcont /CETCOMPAT'
    },
    [pscustomobject]@{
        Name      = 'x64_SEH'
        Arch      = 'x64'
        Toolchain = 'msvc'
        CxxFlags  = '/EHa /GS'
        LdFlags   = ''
    },
    [pscustomobject]@{
        Name      = 'x64_LTCG'
        Arch      = 'x64'
        Toolchain = 'msvc'
        CxxFlags  = '/O2 /GL'
        LdFlags   = '/LTCG'
    },
    [pscustomobject]@{
        Name             = 'x64_Release_LLVM'
        Arch             = 'x64'
        Toolchain        = 'llvm'
        TargetIds        = @('01')
        CxxCompiler      = Join-Path $DefaultLlvmProjectDir 'build\Release\bin\clang++.exe'
        EnvPathPrefix    = Join-Path $DefaultLlvmProjectDir 'build\Release\bin'
        RequiresVSEnv    = $true
        CxxFlags         = '-O2 -g'
        LdFlags          = '-fuse-ld=lld'
    },
    [pscustomobject]@{
        Name             = 'x64_Release_GCC'
        Arch             = 'x64'
        Toolchain        = 'gcc'
        TargetIds        = @('01')
        CxxCompiler      = $DefaultGccCxxCompiler
        EnvPathPrefix    = $DefaultGccPathPrefix
        RequiresVSEnv    = $false
        CxxFlags         = '-O2 -g'
        LdFlags          = ''
    },
    [pscustomobject]@{
        Name             = 'x64_Release_LLVM_CL'
        Arch             = 'x64'
        Toolchain        = 'llvm-cl'
        TargetIds        = @('01')
        CxxCompiler      = Join-Path $Vs2026LlvmBin 'clang-cl.exe'
        EnvPathPrefix    = $Vs2026LlvmBin
        RequiresVSEnv    = $true
        CxxFlags         = '/MT /O2 /GS'
        LdFlags          = ''
    }
)

# ── Target directories ───────────────────────────────────────────────────────
$TargetDirs = [ordered]@{
    '01' = '01-calc-console'
    '02' = '02-gui-license'
    '03' = '03-seh-crash'
    '04' = '04-cpp-exceptions'
    '05' = '05-cfg-testbed'
    '06' = '06-tls-callbacks'
    '07' = '07-dll-plugin-host'
    '08' = '08-multithreaded'
    '09' = '09-file-compressor'
    '10' = '10-large-resource'
    '11' = '11-dll-loader'
    '12' = '12-delay-load'
    '13' = '13-security-hardened'
    '14' = '14-mfc-app'
    '15' = '15-atl-app'
    '16' = '16-winui-app'
    '17' = '17-dotnet-winforms-utility'
    '18' = '18-dotnet-matching-game'
    '19' = '19-dotnet-maui-sample'
    '20' = '20-dotnet-reflection-emit'
    '21' = '21-dotnet-plugin-system'
    '22' = '22-dotnet-wpf-app'
    '23' = '23-dotnet-winforms-sysinfo'
    '24' = '24-c-cli'
    '25' = '25-rust-cli'
    '26' = '26-go-cli'
    '27' = '27-odin-cli'
    '28' = '28-zig-cli'
    '29' = '29-python-tkinter-app'
    '30' = '30-nodejs-gui-app'
    '31' = '31-electron-webview-app'
    '32' = '32-tauri-webview-app'
    '33' = '33-flutter-windows-app'
    '34' = '34-java-swing-app'
    '35' = '35-vbnet-winforms-app'
    '36' = '36-windows-shared-library'
    '37' = '37-linux-shared-library'
    '38' = '38-macos-shared-library'
    '39' = '39-linux-cli-app'
    '40' = '40-macos-cli-app'
    '41' = '41-macos-ui-app'
    '42' = '42-llvm-lit-binaries'
    '43' = '43-asm-cli'
    '44' = '44-delphi-map'
    '45' = '45-linux-executable-variants'
    '46' = '46-macos-executable-variants'
    '47' = '47-gcc-apple-map'
    '48' = '48-gcc-linux-hardened-variants'
    '49' = '49-msvc-map-hardened-variants'
    '50' = '50-ios-app-variants'
    '51' = '51-macos-app-amd64'
    '52' = '52-macos-dll-i386'
    '53' = '53-linux-x64'
    '54' = '54-linux-x86'
    '55' = '55-win32-delphi-i386'
    '56' = '56-win32-exe-i386'
    '57' = '57-win32-dll-i386'
    '58' = '58-windows-driver-variants'
    '59' = '59-uefi-driver'
    '60' = '60-macos-driver-variants'
    '61' = '61-linux-driver-variants'
    '62' = '62-windows-runtime-module'
    '63' = '63-linux-runtime-module'
    '64' = '64-macos-runtime-module'
    '65' = '65-dotnet-il-runtime-modules'
    '66' = '66-driver-runtime-module'
}

# ── Which targets are .NET (use dotnet build instead of cmake) ──────────────
$DotNetTargets = [System.Collections.Generic.HashSet[string]]@(
    '17', '18', '19', '20', '21',
    '22', '23', '35'
)

# ── Which targets are MSBuild vcxproj (use MSBuild instead of cmake) ─────────
$MSBuildTargets = [System.Collections.Generic.HashSet[string]]@(
    '16'
)

# ── Which targets use native toolchains (Rust, Go, Odin, Zig, raw PE) ───────
$NativeTargets = [System.Collections.Generic.HashSet[string]]@(
    '25', '26', '27', '28', '43'
)

$GuiAppTargets = [System.Collections.Generic.HashSet[string]]@(
    '29', '30', '31', '32', '33', '34'
)

$PlatformTargets = [System.Collections.Generic.HashSet[string]]@(
    '37', '38', '39', '40', '41'
)

$LlvmLitTargets = [System.Collections.Generic.HashSet[string]]@(
    '42'
)

$ScriptTargets = [System.Collections.Generic.HashSet[string]]@(
    '44', '45', '46', '47', '48', '49', '50',
    '51', '52', '53', '54', '55', '56', '57',
    '58', '59', '60', '61', '62', '63', '64',
    '65', '66'
)

# ── Filtering ────────────────────────────────────────────────────────────────
$selectedConfigs = @(if ($Configs -eq 'all') { $Matrix } else {
    $names = $Configs -split ',' | ForEach-Object { $_.Trim() }
    $Matrix | Where-Object { $_.Name -in $names }
})

$selectedTargets = @(if ($Targets -eq 'all') {
    $TargetDirs.GetEnumerator() | ForEach-Object { $_ }
} else {
    $ids = $Targets -split ',' | ForEach-Object { $_.Trim().PadLeft(2, '0') }
    $TargetDirs.GetEnumerator() | Where-Object { $_.Key -in $ids }
})

if (-not $selectedConfigs) { Write-Error "No valid configs selected"; exit 1 }
if (-not $selectedTargets) { Write-Error "No valid targets selected"; exit 1 }

if ($OutDir -eq '') { $OutDir = Join-Path $script:Root 'bin' }

# ── Locate MSVC environment ──────────────────────────────────────────────────
function Import-VSEnv {
    param([string]$Arch)
    if ($env:VSINSTALLDIR -and (Test-Path $env:VSINSTALLDIR)) {
        $vsPath = $env:VSINSTALLDIR
    }

    # Try vswhere to find the latest Visual Studio installation.
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not $vsPath -and (Test-Path $vswhere)) {
        $vsPath = & $vswhere -latest -property installationPath 2>$null
    }
    if (-not $vsPath) {
        # Fallback: try common paths
        $candidates = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Enterprise",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise"
        )
        $vsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $vsPath) {
        Write-Error "Cannot find Visual Studio installation.  Set VSINSTALLDIR or run from a Developer Command Prompt."
        exit 1
    }

    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path $vcvars)) {
        Write-Error "vcvarsall.bat not found at $vcvars"
        exit 1
    }

    Restore-BaselineEnvironmentForVsImport

    # Run vcvarsall and import its environment into current process
    $archArg = if ($Arch -eq 'x86') { 'x86' } else { 'amd64' }
    Write-Host "  [vs] $vcvars $archArg" -ForegroundColor DarkGray

    $envBlock = cmd /s /c "`"$vcvars`" $archArg >NUL 2>&1 && set"
    foreach ($line in $envBlock) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }

    # Verify compiler is now reachable
    $cl = (Get-Command cl.exe -ErrorAction SilentlyContinue)
    if (-not $cl) {
        Write-Error "vcvarsall succeeded but cl.exe still not in PATH"
        exit 1
    }
    Write-Host "  [vs] cl.exe: $($cl.Source)" -ForegroundColor DarkGray
}

# ── Build one target under one config ────────────────────────────────────────
function Ensure-VSEnv {
    param([string]$Arch)

    if ($script:CurrentVsArch -ne $Arch) {
        Write-Host "`n>>> Setting up $Arch Visual Studio environment..." -ForegroundColor Blue
        Import-VSEnv -Arch $Arch
        $script:CurrentVsArch = $Arch
    }
}

function Get-CommandPathOrDefault {
    param(
        [string]$CommandName,
        [string]$DefaultPath
    )

    if (-not [string]::IsNullOrWhiteSpace($DefaultPath) -and (Test-Path -LiteralPath $DefaultPath)) {
        return $DefaultPath
    }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        return $cmd.Source
    }

    return ''
}

function Get-JavaHomeForArch {
    param([string]$Arch)

    if ($Arch -eq 'x86') {
        $candidates = @(
            $DefaultJavaX86Root,
            'C:\Program Files (x86)\Java\latest\jre-1.8',
            'C:\Program Files (x86)\Java\jre1.8.0_471'
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath (Join-Path $candidate 'bin\java.exe')) {
                return $candidate
            }
        }
    }

    return ''
}

function Get-ConfigToolchain {
    param($Config)
    if ($Config.PSObject.Properties.Name -contains 'Toolchain' -and -not [string]::IsNullOrWhiteSpace($Config.Toolchain)) {
        return $Config.Toolchain
    }
    return 'msvc'
}

function Test-ConfigRequiresVSEnv {
    param($Config)
    if ($Config.PSObject.Properties.Name -contains 'RequiresVSEnv') {
        return [bool]$Config.RequiresVSEnv
    }
    return (Get-ConfigToolchain $Config) -eq 'msvc'
}

function Test-ConfigAppliesToTarget {
    param(
        $Config,
        [string]$TargetId
    )
    if ($Config.PSObject.Properties.Name -contains 'TargetIds' -and $Config.TargetIds) {
        return @($Config.TargetIds) -contains $TargetId
    }
    return $true
}

function Test-TargetToolchainAvailable {
    param(
        $Config,
        [string]$TargetId,
        [string]$TargetDir
    )
    if ($Config.PSObject.Properties.Name -contains 'CxxCompiler' -and -not [string]::IsNullOrWhiteSpace($Config.CxxCompiler)) {
        if (-not (Test-Path -LiteralPath $Config.CxxCompiler)) {
            Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
            Write-Host "  TARGET: $TargetId ($TargetDir)" -ForegroundColor Yellow
            Write-Host "  CONFIG: $($Config.Name)  |  SKIP (compiler not found)" -ForegroundColor DarkYellow
            Write-Host "  CXX:    $($Config.CxxCompiler)" -ForegroundColor DarkYellow
            Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
            return $false
        }
    }
    return $true
}

function New-ClangGnuMsvcLinkRuleOverride {
    param([string]$BuildDir)

    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

    $overridePath = Join-Path $BuildDir 'clang-gnu-msvc-link-rules.cmake'
    @'
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND WIN32 AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  set(CMAKE_CXX_LINK_EXECUTABLE "<CMAKE_CXX_COMPILER> <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> -Xlinker /MANIFEST:EMBED -Xlinker /implib:<TARGET_IMPLIB> -Xlinker /pdb:<TARGET_PDB> -Xlinker /version:<TARGET_VERSION_MAJOR>.<TARGET_VERSION_MINOR> <LINK_LIBRARIES> <MANIFESTS>")
  set(CMAKE_CXX_CREATE_SHARED_LIBRARY "<CMAKE_CXX_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> -o <TARGET> -Xlinker /MANIFEST:EMBED -Xlinker /implib:<TARGET_IMPLIB> -Xlinker /pdb:<TARGET_PDB> -Xlinker /version:<TARGET_VERSION_MAJOR>.<TARGET_VERSION_MINOR> <OBJECTS> <LINK_LIBRARIES> <MANIFESTS>")
  set(CMAKE_CXX_CREATE_SHARED_MODULE "${CMAKE_CXX_CREATE_SHARED_LIBRARY}")
endif()
'@ | Set-Content -LiteralPath $overridePath -Encoding ASCII

    return $overridePath
}

function Get-CMakeCacheValue {
    param(
        [string[]]$CacheLines,
        [string]$Name
    )

    foreach ($line in $CacheLines) {
        if ($line -match "^$([regex]::Escape($Name)):[^=]*=(.*)$") {
            return $matches[1]
        }
    }
    return ''
}

function Reset-CMakeBuildDirIfStale {
    param(
        [string]$BuildDir,
        [string]$SourceDir,
        [string]$OutputDir,
        $Config,
        [string]$Toolchain
    )

    $cachePath = Join-Path $BuildDir 'CMakeCache.txt'
    if (-not (Test-Path -LiteralPath $cachePath)) {
        return
    }

    $cache = Get-Content -LiteralPath $cachePath -ErrorAction SilentlyContinue
    $staleReasons = @()

    $cachedSource = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_HOME_DIRECTORY'
    if ($cachedSource -and (Get-NormalizedPathForCompare $cachedSource) -ne (Get-NormalizedPathForCompare $SourceDir)) {
        $staleReasons += 'source directory changed'
    }

    $cachedOut = Get-CMakeCacheValue -CacheLines $cache -Name 'MATRIX_OUTPUT_DIR'
    if ($cachedOut -and (Get-NormalizedPathForCompare $cachedOut) -ne (Get-NormalizedPathForCompare $OutputDir)) {
        $staleReasons += 'matrix output directory changed'
    }

    $cachedPointerSize = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_SIZEOF_VOID_P'
    $expectedPointerSize = if ($Config.Arch -eq 'x86') { '4' } else { '8' }
    if ($cachedPointerSize -and $cachedPointerSize -ne $expectedPointerSize) {
        $staleReasons += "cached pointer size is $cachedPointerSize, expected $expectedPointerSize"
    }

    if ($Toolchain -eq 'msvc') {
        $expectedCl = Get-Command cl.exe -ErrorAction SilentlyContinue
        $cachedC = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_C_COMPILER'
        $cachedCxx = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_CXX_COMPILER'
        if ($expectedCl -and $cachedC -and (Get-NormalizedPathForCompare $cachedC) -ne (Get-NormalizedPathForCompare $expectedCl.Source)) {
            $staleReasons += 'MSVC C compiler changed'
        }
        if ($expectedCl -and $cachedCxx -and (Get-NormalizedPathForCompare $cachedCxx) -ne (Get-NormalizedPathForCompare $expectedCl.Source)) {
            $staleReasons += 'MSVC CXX compiler changed'
        }
    }
    elseif ($Config.PSObject.Properties.Name -contains 'CxxCompiler' -and -not [string]::IsNullOrWhiteSpace($Config.CxxCompiler)) {
        $cachedC = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_C_COMPILER'
        $cachedCxx = Get-CMakeCacheValue -CacheLines $cache -Name 'CMAKE_CXX_COMPILER'
        if ($cachedC -and (Get-NormalizedPathForCompare $cachedC) -ne (Get-NormalizedPathForCompare $Config.CxxCompiler)) {
            $staleReasons += 'configured C compiler changed'
        }
        if ($cachedCxx -and (Get-NormalizedPathForCompare $cachedCxx) -ne (Get-NormalizedPathForCompare $Config.CxxCompiler)) {
            $staleReasons += 'configured CXX compiler changed'
        }
    }

    if ($staleReasons.Count -gt 0) {
        Write-Host "  [clean] removing stale CMake build directory: $($staleReasons -join '; ')" -ForegroundColor DarkYellow
        Remove-BuildDirectorySafely -BuildDir $BuildDir
    }
}

function Build-Target {
    param(
        $Config,
        $TargetId,
        $TargetDir
    )
    $buildDir = Join-Path $script:Root "build\$($TargetId)_$($Config.Name)"
    $outSub   = Join-Path $OutDir $Config.Name
    $srcDir   = Join-Path $script:Root $TargetDir

    if ($Clean -and (Test-Path $buildDir)) {
        Remove-BuildDirectorySafely -BuildDir $buildDir
    }

    New-Item -ItemType Directory -Force -Path $outSub | Out-Null

    if (-not (Test-TargetToolchainAvailable -Config $Config -TargetId $TargetId -TargetDir $TargetDir)) {
        return $true
    }

    $toolchain = Get-ConfigToolchain $Config
    if (Test-ConfigRequiresVSEnv $Config) {
        Ensure-VSEnv -Arch $Config.Arch
    }
    Reset-CMakeBuildDirIfStale -BuildDir $buildDir -SourceDir $srcDir -OutputDir $outSub -Config $Config -Toolchain $toolchain

    $cmakeArgs = @(
        '-G', 'Ninja',
        '-S', $srcDir,
        '-B', $buildDir,
        '-DCMAKE_BUILD_TYPE=Release',
        "-DMATRIX_CXX_FLAGS=$($Config.CxxFlags -replace ' ',';')",
        "-DMATRIX_LD_FLAGS=$($Config.LdFlags -replace ' ',';')",
        "-DMATRIX_OUTPUT_DIR=$outSub"
    )

    if ($Config.PSObject.Properties.Name -contains 'CxxCompiler' -and -not [string]::IsNullOrWhiteSpace($Config.CxxCompiler)) {
        $cmakeArgs += "-DCMAKE_CXX_COMPILER=$($Config.CxxCompiler)"
    }
    if ($toolchain -eq 'llvm') {
        $overridePath = New-ClangGnuMsvcLinkRuleOverride -BuildDir $buildDir
        $cmakeArgs += "-DCMAKE_USER_MAKE_RULES_OVERRIDE_CXX=$overridePath"
    }
    if ($toolchain -ne 'msvc') {
        $cmakeArgs += "-DCMAKE_CXX_FLAGS_RELEASE=$($Config.CxxFlags)"
        $cmakeArgs += "-DCMAKE_EXE_LINKER_FLAGS=$($Config.LdFlags)"
    }

    $oldPath = $env:PATH
    if ($Config.PSObject.Properties.Name -contains 'EnvPathPrefix' -and -not [string]::IsNullOrWhiteSpace($Config.EnvPathPrefix)) {
        $env:PATH = "$($Config.EnvPathPrefix);$env:PATH"
    }

    # Ninja does NOT support -A; the target arch is set by the toolchain environment.
    Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  TARGET: $TargetId ($TargetDir)" -ForegroundColor Yellow
    Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $($Config.Arch)" -ForegroundColor Yellow
    Write-Host "  TOOL:   $toolchain" -ForegroundColor DarkYellow
    if ($Config.PSObject.Properties.Name -contains 'CxxCompiler' -and -not [string]::IsNullOrWhiteSpace($Config.CxxCompiler)) {
        Write-Host "  CXXBIN: $($Config.CxxCompiler)" -ForegroundColor DarkYellow
    }
    Write-Host "  CXX:    $($Config.CxxFlags)" -ForegroundColor DarkYellow
    Write-Host "  LD:     $($Config.LdFlags)" -ForegroundColor DarkYellow
    Write-Host "  OUT:    $outSub" -ForegroundColor DarkYellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

    try {
        # Configure
        Write-Host "  [cmake] configuring..." -ForegroundColor White
        $cfgResult = & cmake @cmakeArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [FAIL] cmake configure failed" -ForegroundColor Red
            Write-Host $cfgResult
            return $false
        }

        if (-not $NoBuild) {
            Write-Host "  [cmake] building..." -ForegroundColor White
            $buildResult = cmake --build $buildDir 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [FAIL] cmake build failed" -ForegroundColor Red
                Write-Host $buildResult
                return $false
            }
            # Show what was produced
            $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.exe,*.dll,*.pdb 2>$null
            if ($artifacts) {
                Write-Host "  [OK]   artifacts:" -ForegroundColor Green
                foreach ($a in $artifacts) {
                    $size = '{0,8:N0} KB' -f ($a.Length / 1KB)
                    Write-Host "         $($a.Name)  $size" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "  [OK]   configured (--no-build)" -ForegroundColor Green
        }
        return $true
    }
    finally {
        $env:PATH = $oldPath
    }
}


# ── Build one .NET target under one config ────────────────────────────────────
function Build-DotNetTarget {
    param(
        $Config,
        $TargetId,
        $TargetDir
    )
    $srcDir   = Join-Path $script:Root $TargetDir
    $outBase  = Join-Path $OutDir $Config.Name

    $project = Get-ChildItem -Path $srcDir -File | Where-Object { $_.Extension -in '.csproj', '.vbproj' } | Select-Object -First 1
    if (-not $project) {
        Write-Host "  [FAIL] No .NET project found in $srcDir" -ForegroundColor Red
        return $false
    }

    # Isolate .NET outputs in their own project subdirectory
    $projName = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)
    $outSub   = Join-Path $outBase $projName

    New-Item -ItemType Directory -Force -Path $outSub | Out-Null

    $dotnetConfig = if ($Config.Name -like '*Debug*') { 'Debug' } else { 'Release' }
    $dotnetArch   = if ($Config.Arch -eq 'x86') { 'x86' } else { 'x64' }
    $rid          = if ($Config.Arch -eq 'x86') { 'win-x86' } else { 'win-x64' }

    $dotnetArgs = @(
        'build', $project.FullName,
        '-c', $dotnetConfig,
        '-r', $rid,
        '--self-contained', 'false',
        '-o', $outSub
    )

    if ($Config.Arch -eq 'x86') {
        $dotnetArgs += '/p:PlatformTarget=x86'
    }
    if ($Config.Name -eq 'x64_LTCG') {
        $dotnetArgs += '/p:PublishReadyToRun=true'
    }

    Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  TARGET: $TargetId ($TargetDir) [.NET]" -ForegroundColor Yellow
    Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $dotnetArch" -ForegroundColor Yellow
    Write-Host "  DOTNET: dotnet $($dotnetArgs -join ' ')" -ForegroundColor DarkYellow
    Write-Host "  OUT:    $outSub" -ForegroundColor DarkYellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

    $result = & dotnet $dotnetArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] dotnet build failed" -ForegroundColor Red
        Write-Host ($result -join "`n")
        return $false
    }

    $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.exe,*.dll 2>$null
    if ($artifacts) {
        Write-Host "  [OK]   artifacts:" -ForegroundColor Green
        foreach ($a in $artifacts) {
            $size = '{0,8:N0} KB' -f ($a.Length / 1KB)
            Write-Host "         $($a.Name)  $size" -ForegroundColor Green
        }
    }
    return $true
}

# ── Build one MSBuild vcxproj target under one config ────────────────────────
function Build-MSBuildTarget {
    param(
        $Config,
        $TargetId,
        $TargetDir
    )
    $srcDir   = Join-Path $script:Root $TargetDir
    $outBase  = Join-Path $OutDir $Config.Name

    $outSub   = Join-Path $outBase 'WinUIApp'

    $vsCfg   = if ($Config.Name -like '*Debug*') { 'Debug' } else { 'Release' }
    $arch    = if ($Config.Arch -eq 'x86') { 'Win32' } else { 'x64' }

    $msbuild = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'

    $vcxproj = Get-ChildItem -Path $srcDir -Filter *.vcxproj -File | Select-Object -First 1
    if (-not $vcxproj) {
        Write-Host "  [FAIL] No .vcxproj found in $srcDir" -ForegroundColor Red
        return $false
    }

    New-Item -ItemType Directory -Force -Path $outSub | Out-Null

    Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  TARGET: $TargetId ($TargetDir) [MSBuild vcxproj]" -ForegroundColor Yellow
    Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $arch" -ForegroundColor Yellow
    Write-Host "  MSBUILD: $($vcxproj.Name)" -ForegroundColor DarkYellow
    Write-Host "  OUT:    $outSub" -ForegroundColor DarkYellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

    # Clean first if requested
    if ($Clean -and (Test-Path (Join-Path $srcDir $arch))) {
        Remove-Item -Recurse -Force (Join-Path $srcDir $arch) -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse -Force "$srcDir\obj" -ErrorAction SilentlyContinue

    $buildResult = & $msbuild $vcxproj.FullName `
        "/p:Configuration=$vsCfg" `
        "/p:Platform=$arch" `
        "/p:MatrixOutSubdir=$($Config.Name)" `
        "/v:minimal" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] MSBuild failed" -ForegroundColor Red
        Write-Host ($buildResult -join "`n")
        return $false
    }

    # Copy outputs to the matrix bin directory
    $buildOut = Join-Path $srcDir "$arch\$vsCfg\WinUIApp"
    if (Test-Path $buildOut) {
        Copy-Item -Path "$buildOut\*" -Destination $outSub -Recurse -Force
    }

    $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.exe,*.dll,*.pdb 2>$null
    if ($artifacts) {
        Write-Host "  [OK]   artifacts:" -ForegroundColor Green
        foreach ($a in $artifacts) {
            $size = '{0,8:N0} KB' -f ($a.Length / 1KB)
            Write-Host "         $($a.Name)  $size" -ForegroundColor Green
        }
    }
    return $true
}

# ── Native toolchain targets (Rust, Go, Odin, Zig, raw PE) ──────────────────
function Build-NativeTarget {
 param($Config, $TargetId, $TargetDir)

 $srcDir = Join-Path $script:Root $TargetDir
 $outSub = Join-Path $OutDir $Config.Name
 $arch   = if ($Config.Arch -eq 'x86') { 'x86' } else { 'x64' }
 $vsCfg  = if ($Config.Name -like '*Debug*') { 'debug' } else { 'release' }

 switch ($TargetId) {
     '25' {
         # Rust
         if ($arch -eq 'x86') {
             $rustTarget = 'i686-pc-windows-msvc'
             $installed = & rustup target list --installed 2>$null
             if ($installed -notcontains $rustTarget) {
                 Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
                 Write-Host "  TARGET: $TargetId ($TargetDir) [Rust]" -ForegroundColor Yellow
                 Write-Host "  CONFIG: $($Config.Name)  |  SKIP (x86 target not installed)" -ForegroundColor DarkYellow
                 Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
                 return $true
             }
         } else {
             $rustTarget = 'x86_64-pc-windows-msvc'
        }
        $profileDir = if ($vsCfg -eq 'debug') { 'debug' } else { 'release' }
        $manifest   = Join-Path $srcDir 'Cargo.toml'

        Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  TARGET: $TargetId ($TargetDir) [Rust]" -ForegroundColor Yellow
        Write-Host "  CONFIG: $($Config.Name)  |  TARGET: $rustTarget" -ForegroundColor DarkYellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

        Write-Host "  [cargo] building... " -ForegroundColor White -NoNewline
        $relFlag = if ($vsCfg -ne 'debug') { '--release' } else { '' }
        $cmd = "cargo build --quiet --target $rustTarget $relFlag --manifest-path `"$manifest`""
        $null = cmd /c "$cmd" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
            return $false
        }
        Write-Host "OK" -ForegroundColor Green

        $cargoExe = Join-Path $srcDir "target\$rustTarget\$profileDir\rust-cli.exe"
        if (Test-Path $cargoExe) {
            New-Item -ItemType Directory -Force -Path $outSub | Out-Null
            Copy-Item $cargoExe (Join-Path $outSub 'rust_cli.exe') -Force
        } else {
            # Older cargo may use underscore
            $cargoExeOld = Join-Path $srcDir "target\$rustTarget\$profileDir\rust_cli.exe"
            if (Test-Path $cargoExeOld) {
                Copy-Item $cargoExeOld (Join-Path $outSub 'rust_cli.exe') -Force
            }
        }
    }
     '26' {
         # Go
         $goExe = (Get-Command go -ErrorAction SilentlyContinue)
         if (-not $goExe) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Go]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (Go not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $env:GOARCH = if ($arch -eq 'x86') { '386' } else { 'amd64' }
         $env:GOOS    = 'windows'
         $outFile     = Join-Path $outSub 'go_cli.exe'

         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Go]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  GOARCH: $env:GOARCH" -ForegroundColor DarkYellow
         Write-Host "----------------------------------------------------------------" -foregroundColor Cyan

         New-Item -ItemType Directory -Force -Path $outSub | Out-Null
         $result = & go build -ldflags='-s -w' -o $outFile (Join-Path $srcDir 'main.go') 2>&1
         if ($LASTEXITCODE -ne 0) {
             Write-Host "  [FAIL] go build" -ForegroundColor Red
             Write-Host ($result -join "`n")
             return $false
         }
     }
     '27' {
         # Odin
         $odinExe = (Get-Command odin -ErrorAction SilentlyContinue)
         if (-not $odinExe) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Odin]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (Odin not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
        $odinTarget = if ($arch -eq 'x86') { 'windows_i386' } else { 'windows_amd64' }
        $odinOpt    = if ($vsCfg -eq 'debug') { 'none' } else { 'speed' }
        $outFile  = Join-Path $outSub 'odin_cli.exe'

        Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  TARGET: $TargetId ($TargetDir) [Odin]" -ForegroundColor Yellow
        Write-Host "  CONFIG: $($Config.Name)  |  TARGET: $odinTarget" -ForegroundColor DarkYellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

        New-Item -ItemType Directory -Force -Path $outSub | Out-Null
        $odinCmd = "odin build `"$srcDir`" -out:`"$outFile`" -target:$odinTarget -o:$odinOpt 2>&1"
        cmd /c "$odinCmd" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
            return $false
        }
        Write-Host "OK" -ForegroundColor Green
    }
     '28' {
         # Zig
         $zigExe = (Get-Command zig -ErrorAction SilentlyContinue)
         if (-not $zigExe) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Zig]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (Zig not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $zigTarget = if ($arch -eq 'x86') { 'x86-windows-msvc' } else { 'x86_64-windows-msvc' }
         $outFile   = Join-Path $outSub 'zig_cli.exe'
         $opt       = if ($vsCfg -eq 'debug') { 'Debug' } else { 'ReleaseSafe' }

         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Zig]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  TARGET: $zigTarget" -ForegroundColor DarkYellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

         New-Item -ItemType Directory -Force -Path $outSub | Out-Null
         $buildDir = Join-Path $script:Root "build\$($TargetId)_$($Config.Name)_zig"
         Write-Host "  [zig] building... " -ForegroundColor White -NoNewline
         $zigCmd = "zig build-exe `"$(Join-Path $srcDir 'src/main.zig')`" -target $zigTarget -femit-bin=`"$outFile`" -fno-emit-implib -O $opt --cache-dir `"$buildDir`" --name zig_cli"
         $null = cmd /c "$zigCmd" 2>&1
         if ($LASTEXITCODE -ne 0) {
             Write-Host "FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
             return $false
         }
         Write-Host "OK" -ForegroundColor Green
     }
     '43' {
         # Tiny raw PE32 executable (raw bytes; no assembler/linker)
         $scriptPath = Join-Path $srcDir 'build.ps1'
         $asmConfig = if ($vsCfg -eq 'debug') { 'Debug' } else { 'Release' }

         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [raw PE]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  ARCH REQUEST: $arch" -ForegroundColor DarkYellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

         $asmArgs = @(
             '-NoProfile',
             '-ExecutionPolicy', 'Bypass',
             '-File', $scriptPath,
             '-Arch', $arch,
             '-Configuration', $asmConfig,
             '-OutDir', $outSub,
             '-SkipIfUnavailable'
         )
         if ($Clean) {
             $asmArgs += '-Clean'
         }

         $result = & powershell @asmArgs 2>&1
         Write-Host ($result -join "`n")
         if ($LASTEXITCODE -ne 0) {
             Write-Host "  [FAIL] raw PE build" -ForegroundColor Red
             return $false
         }
     }
 }

 $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.exe,*.dll 2>$null
 if ($artifacts) {
     Write-Host "  [OK]   artifacts:" -ForegroundColor Green
     foreach ($a in $artifacts) {
         $size = '{0,8:N0} KB' -f ($a.Length / 1KB)
         Write-Host "         $($a.Name)  $size" -ForegroundColor Green
     }
 }
 return $true
}

# ── GUI app targets (Python, Node.js, Electron, Tauri, Flutter, Java) ────────
function Build-GuiAppTarget {
 param($Config, $TargetId, $TargetDir)

 $srcDir = Join-Path $script:Root $TargetDir
 $outSub = Join-Path $OutDir $Config.Name
 $arch   = if ($Config.Arch -eq 'x86') { 'x86' } else { 'x64' }
 $vsCfg  = if ($Config.Name -like '*Debug*') { 'Debug' } else { 'Release' }

 New-Item -ItemType Directory -Force -Path $outSub | Out-Null

 switch ($TargetId) {
     '29' {
         $pythonExe = if ($arch -eq 'x86') {
             Join-Path $DefaultPythonX86Root 'python.exe'
         } else {
             Get-CommandPathOrDefault -CommandName 'python.exe' -DefaultPath ''
         }
         if ([string]::IsNullOrWhiteSpace($pythonExe) -or -not (Test-Path -LiteralPath $pythonExe)) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Python/Tkinter]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (python not installed for $arch)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $workDir = Join-Path $script:Root "build\$($TargetId)_$($Config.Name)_pyinstaller"
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Python/Tkinter]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $arch" -ForegroundColor Yellow
         Write-Host "  PYTHON: $pythonExe" -ForegroundColor DarkYellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         if ($Clean -and (Test-Path $workDir)) { Remove-BuildDirectorySafely -BuildDir $workDir }
         $mainPy = Join-Path $srcDir 'main.py'
         $pyArgs = @(
             '-m', 'PyInstaller',
             '--noconfirm',
             '--clean',
             '--onefile',
             '--windowed',
             '--name', 'python_tkinter_app',
             '--distpath', $outSub,
             '--workpath', $workDir,
             '--specpath', $workDir,
             $mainPy
         )
         $captured = Invoke-NativeCaptured -FilePath $pythonExe -ArgumentList $pyArgs
         $result = $captured.Output
         if ($captured.ExitCode -ne 0) {
             Write-Host "  [FAIL] pyinstaller" -ForegroundColor Red
             Write-Host ($result -join "`n")
             return $false
         }
     }
     '30' {
         $nodeBin = if ($arch -eq 'x86') { $DefaultNodeX86Root } else { '' }
         $nodeExe = if ($arch -eq 'x86') { Join-Path $nodeBin 'node.exe' } else { Get-CommandPathOrDefault -CommandName 'node.exe' -DefaultPath '' }
         $npmExe = if ($arch -eq 'x86') { Join-Path $nodeBin 'npm.cmd' } else { Get-CommandPathOrDefault -CommandName 'npm.cmd' -DefaultPath '' }
         $npxExe = if ($arch -eq 'x86') { Join-Path $nodeBin 'npx.cmd' } else { Get-CommandPathOrDefault -CommandName 'npx.cmd' -DefaultPath '' }
         if ([string]::IsNullOrWhiteSpace($nodeExe) -or [string]::IsNullOrWhiteSpace($npmExe) -or [string]::IsNullOrWhiteSpace($npxExe) -or
             -not (Test-Path -LiteralPath $nodeExe) -or -not (Test-Path -LiteralPath $npmExe) -or -not (Test-Path -LiteralPath $npxExe)) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Node.js/pkg]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (node or npm not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $pkgTarget = if ($arch -eq 'x86') { 'node22-win-x86 SEA' } else { 'node18-win-x64' }
         $outFile = Join-Path $outSub 'nodejs_gui_app.exe'
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Node.js/pkg]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  TARGET: $pkgTarget" -ForegroundColor Yellow
         Write-Host "  NODE:   $nodeExe" -ForegroundColor DarkYellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         $oldPath = $env:PATH
         try {
             $pathPrefixes = @($nodeBin)
             if (Test-Path -LiteralPath (Join-Path $DefaultPatchBin 'patch.exe')) {
                 $pathPrefixes += $DefaultPatchBin
             }
             $pathPrefixes = $pathPrefixes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
             if ($pathPrefixes) {
                 $env:PATH = (($pathPrefixes + @($env:PATH)) -join ';')
             }
             Push-Location $srcDir
             try {
                 if ($arch -eq 'x86') {
                     $seaWorkDir = Join-Path $script:Root "build\$($TargetId)_$($Config.Name)_node_sea"
                     if ($Clean -and (Test-Path -LiteralPath $seaWorkDir)) {
                         Remove-BuildDirectorySafely -BuildDir $seaWorkDir
                     }
                     New-Item -ItemType Directory -Force -Path $seaWorkDir | Out-Null

                     $seaBlob = Join-Path $seaWorkDir 'sea-prep.blob'
                     $seaConfig = Join-Path $seaWorkDir 'sea-config.json'
                     [pscustomobject]@{
                         main = Join-Path $srcDir 'main.js'
                         output = $seaBlob
                         disableExperimentalSEAWarning = $true
                     } | ConvertTo-Json | Set-Content -LiteralPath $seaConfig -Encoding ASCII

                     $captured = Invoke-NativeCaptured -FilePath $nodeExe -ArgumentList @('--experimental-sea-config', $seaConfig) -WorkingDirectory $srcDir
                     $result = $captured.Output
                     if ($captured.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $seaBlob)) {
                         Write-Host "  [FAIL] node SEA blob" -ForegroundColor Red
                         Write-Host ($result -join "`n")
                         return $false
                     }

                     Copy-Item -LiteralPath $nodeExe -Destination $outFile -Force
                     $captured = Invoke-NativeCaptured -FilePath $npxExe -ArgumentList @('--yes', 'postject', $outFile, 'NODE_SEA_BLOB', $seaBlob, '--sentinel-fuse', 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2', '--overwrite') -WorkingDirectory $srcDir
                     $result = $captured.Output
                     if ($captured.ExitCode -ne 0) {
                         Write-Host "  [FAIL] node SEA inject" -ForegroundColor Red
                         Write-Host ($result -join "`n")
                         return $false
                     }
                 }
                 else {
                     if (-not (Test-Path (Join-Path $srcDir 'node_modules'))) {
                         $captured = Invoke-NativeCaptured -FilePath $npmExe -ArgumentList @('install', '--silent') -WorkingDirectory $srcDir
                         $install = $captured.Output
                         if ($captured.ExitCode -ne 0) {
                             Write-Host "  [FAIL] npm install" -ForegroundColor Red
                             Write-Host ($install -join "`n")
                             return $false
                         }
                     }
                     $captured = Invoke-NativeCaptured -FilePath $npxExe -ArgumentList @('pkg', '.', '--targets', $pkgTarget, '--output', $outFile) -WorkingDirectory $srcDir
                     $result = $captured.Output
                     if ($captured.ExitCode -ne 0) {
                         Write-Host "  [FAIL] pkg" -ForegroundColor Red
                         Write-Host ($result -join "`n")
                         return $false
                     }
                 }
             }
             finally {
                 Pop-Location
             }
         }
         finally {
             $env:PATH = $oldPath
         }
     }
     '31' {
         $node = Get-Command node -ErrorAction SilentlyContinue
         $npm = Get-Command npm -ErrorAction SilentlyContinue
         if (-not $node -or -not $npm) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Electron]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (node or npm not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $electronArch = if ($arch -eq 'x86') { 'ia32' } else { 'x64' }
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Electron]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $electronArch" -ForegroundColor Yellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         if (-not (Test-Path (Join-Path $srcDir 'node_modules'))) {
             $install = cmd /c "cd /d `"$srcDir`" && npm install --silent" 2>&1
             if ($LASTEXITCODE -ne 0) {
                 Write-Host "  [FAIL] npm install" -ForegroundColor Red
                 Write-Host ($install -join "`n")
                 return $false
             }
         }
         $distDir = Join-Path $srcDir 'dist'
         if ($Clean -and (Test-Path $distDir)) { Remove-Item -Recurse -Force $distDir }
         $result = cmd /c "cd /d `"$srcDir`" && npx electron-packager . electron_webview_app --platform=win32 --arch=$electronArch --overwrite --out=dist 2>&1"
         if ($LASTEXITCODE -ne 0) {
             Write-Host "  [FAIL] electron-packager" -ForegroundColor Red
             Write-Host ($result -join "`n")
             return $false
         }
         $packageDir = Join-Path $distDir "electron_webview_app-win32-$electronArch"
         $destDir = Join-Path $outSub 'electron_webview_app'
         if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
         Copy-Item $packageDir $destDir -Recurse -Force
     }
     '32' {
         $cargo = Get-Command cargo -ErrorAction SilentlyContinue
         $nodeBin = if ($arch -eq 'x86') { $DefaultNodeX86Root } else { '' }
         $nodeExe = if ($arch -eq 'x86') { Join-Path $nodeBin 'node.exe' } else { Get-CommandPathOrDefault -CommandName 'node.exe' -DefaultPath '' }
         $npmExe = if ($arch -eq 'x86') { Join-Path $nodeBin 'npm.cmd' } else { Get-CommandPathOrDefault -CommandName 'npm.cmd' -DefaultPath '' }
         if (-not $cargo -or [string]::IsNullOrWhiteSpace($nodeExe) -or [string]::IsNullOrWhiteSpace($npmExe) -or
             -not (Test-Path -LiteralPath $nodeExe) -or -not (Test-Path -LiteralPath $npmExe)) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Tauri]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (cargo, node, or npm not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $rustTarget = if ($arch -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Tauri]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  TARGET: $rustTarget" -ForegroundColor Yellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         $installedTargets = & rustup target list --installed 2>$null
         if ($installedTargets -notcontains $rustTarget) {
             $rustup = & rustup target add $rustTarget 2>&1
             if ($LASTEXITCODE -ne 0) {
                 Write-Host "  [FAIL] rustup target add $rustTarget" -ForegroundColor Red
                 Write-Host ($rustup -join "`n")
                 return $false
             }
         }
         $oldPath = $env:PATH
         try {
             if (-not [string]::IsNullOrWhiteSpace($nodeBin)) {
                 $env:PATH = "$nodeBin;$env:PATH"
             }
             Push-Location $srcDir
             try {
                 if (($arch -eq 'x86') -or -not (Test-Path (Join-Path $srcDir 'node_modules'))) {
                     $captured = Invoke-NativeCaptured -FilePath $npmExe -ArgumentList @('install', '--silent') -WorkingDirectory $srcDir
                     $install = $captured.Output
                     if ($captured.ExitCode -ne 0) {
                         Write-Host "  [FAIL] npm install" -ForegroundColor Red
                         Write-Host ($install -join "`n")
                         return $false
                     }
                 }
                 $captured = Invoke-NativeCaptured -FilePath $npmExe -ArgumentList @('run', 'tauri', 'build', '--', '--target', $rustTarget) -WorkingDirectory $srcDir
                 $result = $captured.Output
                 if ($captured.ExitCode -ne 0) {
                     Write-Host "  [FAIL] tauri build" -ForegroundColor Red
                     Write-Host ($result -join "`n")
                     return $false
                 }
             }
             finally {
                 Pop-Location
             }
         }
         finally {
             $env:PATH = $oldPath
         }
         $exe = Join-Path $srcDir "src-tauri\target\$rustTarget\release\tauri_webview_app.exe"
         if (Test-Path $exe) { Copy-Item $exe (Join-Path $outSub 'tauri_webview_app.exe') -Force }
     }
     '33' {
         $flutter = Get-Command flutter -ErrorAction SilentlyContinue
         if (-not $flutter) {
             $env:Path = @($env:Path, [Environment]::GetEnvironmentVariable('Path','Machine'), [Environment]::GetEnvironmentVariable('Path','User')) -join ';'
             $flutter = Get-Command flutter -ErrorAction SilentlyContinue
         }
         if (-not $flutter) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Flutter Windows]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (flutter not installed)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         if ($arch -eq 'x86') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Flutter Windows]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (Flutter Windows is x64-only here)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Flutter Windows]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  ARCH: x64" -ForegroundColor Yellow
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         $flutterCmd = $flutter.Source
         if (-not (Test-Path (Join-Path $srcDir 'windows'))) {
             $create = cmd /c "cd /d `"$srcDir`" && `"$flutterCmd`" create --platforms=windows --project-name flutter_webview_victim . 2>&1"
             if ($LASTEXITCODE -ne 0) {
                 Write-Host "  [FAIL] flutter create" -ForegroundColor Red
                 Write-Host ($create -join "`n")
                 return $false
             }
         }
         $flutterWindowsBuild = Join-Path $srcDir 'build\windows'
         $flutterCmakeCache = Join-Path $flutterWindowsBuild 'x64\CMakeCache.txt'
         if (Test-Path -LiteralPath $flutterCmakeCache) {
             $expectedSource = ((Join-Path $srcDir 'windows') -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
             $cacheSource = ''
             foreach ($line in Get-Content -LiteralPath $flutterCmakeCache -ErrorAction SilentlyContinue) {
                 if ($line -match '^CMAKE_HOME_DIRECTORY:INTERNAL=(.+)$') {
                     $cacheSource = ($matches[1] -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
                     break
                 }
             }
             if ($cacheSource -and $cacheSource -ne $expectedSource) {
                 Write-Host "  [clean] removing stale Flutter CMake cache from $cacheSource" -ForegroundColor DarkYellow
                 Remove-Item -LiteralPath $flutterWindowsBuild -Recurse -Force
             }
         }
         $result = cmd /c "cd /d `"$srcDir`" && `"$flutterCmd`" build windows --$($vsCfg.ToLowerInvariant()) 2>&1"
         if ($LASTEXITCODE -ne 0) {
             Write-Host "  [FAIL] flutter build" -ForegroundColor Red
             Write-Host ($result -join "`n")
             return $false
         }
         $buildOut = Join-Path $srcDir "build\windows\x64\runner\$vsCfg"
         $destDir = Join-Path $outSub 'flutter_webview_app'
         if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
         Copy-Item $buildOut $destDir -Recurse -Force
     }
     '34' {
         $javaHome = Get-JavaHomeForArch -Arch $arch
         $javacDefault = if ($javaHome) { Join-Path $javaHome 'bin\javac.exe' } else { '' }
         $jarDefault = if ($javaHome) { Join-Path $javaHome 'bin\jar.exe' } else { '' }
         $javacExe = Get-CommandPathOrDefault -CommandName 'javac.exe' -DefaultPath $javacDefault
         $jarExe = Get-CommandPathOrDefault -CommandName 'jar.exe' -DefaultPath $jarDefault
         $jpackageExe = if ($arch -eq 'x86') { '' } else { Get-CommandPathOrDefault -CommandName 'jpackage.exe' -DefaultPath '' }
         $javaRuntimeExe = if ($javaHome) { Join-Path $javaHome 'bin\java.exe' } else { Get-CommandPathOrDefault -CommandName 'java.exe' -DefaultPath '' }
         if ([string]::IsNullOrWhiteSpace($javacExe) -or [string]::IsNullOrWhiteSpace($jarExe) -or
             -not (Test-Path -LiteralPath $javacExe) -or -not (Test-Path -LiteralPath $jarExe) -or
             ($arch -eq 'x86' -and (-not (Test-Path -LiteralPath $javaRuntimeExe))) -or
             ($arch -ne 'x86' -and ([string]::IsNullOrWhiteSpace($jpackageExe) -or -not (Test-Path -LiteralPath $jpackageExe)))) {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Java Swing]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (required Java tools/runtime not installed for $arch)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $buildDir = Join-Path $script:Root "build\$($TargetId)_$($Config.Name)_java"
         $classes = Join-Path $buildDir 'classes'
         $jarDir = Join-Path $buildDir 'jar'
         Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
         Write-Host "  TARGET: $TargetId ($TargetDir) [Java Swing]" -ForegroundColor Yellow
         Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $arch" -ForegroundColor Yellow
         Write-Host "  JAVAC:  $javacExe" -ForegroundColor DarkYellow
         if ($arch -eq 'x86') { Write-Host "  JAVA:   $javaRuntimeExe" -ForegroundColor DarkYellow }
         Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
         if ($Clean -and (Test-Path $buildDir)) { Remove-BuildDirectorySafely -BuildDir $buildDir }
         New-Item -ItemType Directory -Force -Path $classes, $jarDir | Out-Null
         $source = Join-Path $srcDir 'src\main\java\protector\victims\JavaSwingVictim.java'
         $captured = Invoke-NativeCaptured -FilePath $javacExe -ArgumentList @('-source', '8', '-target', '8', '-d', $classes, $source)
         $compile = $captured.Output
         if ($captured.ExitCode -ne 0) {
             Write-Host "  [FAIL] javac" -ForegroundColor Red
             Write-Host ($compile -join "`n")
             return $false
         }
         $jarFile = Join-Path $jarDir 'java_swing_app.jar'
         $captured = Invoke-NativeCaptured -FilePath $jarExe -ArgumentList @('cfe', $jarFile, 'protector.victims.JavaSwingVictim', '-C', $classes, '.')
         $jarResult = $captured.Output
         if ($captured.ExitCode -ne 0) {
             Write-Host "  [FAIL] jar" -ForegroundColor Red
             Write-Host ($jarResult -join "`n")
             return $false
         }
         $appDir = Join-Path $outSub 'java_swing_app'
         if (Test-Path $appDir) { Remove-Item -Recurse -Force $appDir }
         if ($arch -eq 'x86') {
             New-Item -ItemType Directory -Force -Path $appDir | Out-Null
             Copy-Item -LiteralPath $jarFile -Destination (Join-Path $appDir 'java_swing_app.jar') -Force
             $launcher = @"
@echo off
"$javaRuntimeExe" -jar "%~dp0java_swing_app.jar" %*
"@
             $launcher | Set-Content -LiteralPath (Join-Path $appDir 'java_swing_app.cmd') -Encoding ASCII
         }
         else {
             $captured = Invoke-NativeCaptured -FilePath $jpackageExe -ArgumentList @('--type', 'app-image', '--name', 'java_swing_app', '--input', $jarDir, '--main-jar', 'java_swing_app.jar', '--dest', $outSub)
             $pkgResult = $captured.Output
             if ($captured.ExitCode -ne 0) {
                 Write-Host "  [FAIL] jpackage" -ForegroundColor Red
                 Write-Host ($pkgResult -join "`n")
                 return $false
             }
         }
     }
 }

 $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.exe,*.dll,*.jar,*.cmd 2>$null
 if ($artifacts) {
     Write-Host "  [OK]   artifacts:" -ForegroundColor Green
     foreach ($a in $artifacts) {
         $size = '{0,8:N0} KB' -f ($a.Length / 1KB)
         Write-Host "         $($a.Name)  $size" -ForegroundColor Green
     }
 }
return $true
}

function Get-HostPlatformName {
    $isLinuxValue = Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue
    $isMacValue = Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue
    if ($isLinuxValue) { return 'linux' }
    if ($isMacValue) { return 'macos' }
    return 'windows'
}

function ConvertTo-WslPath {
 param([string]$Path)

 $fullPath = [System.IO.Path]::GetFullPath($Path)
 if ($fullPath -match '^([A-Za-z]):[\\/](.*)$') {
     $drive = $matches[1].ToLowerInvariant()
     $rest = $matches[2] -replace '\\', '/'
     return "/mnt/$drive/$rest"
 }

 $converted = & wsl.exe wslpath -a -- $fullPath 2>&1
 if ($LASTEXITCODE -ne 0) {
     throw "wslpath failed for '$fullPath': $($converted -join ' ')"
 }
 return ($converted | Select-Object -First 1)
}

function Quote-NativeArgument {
 param([string]$Argument)

 if ($null -eq $Argument) { return '""' }
 if ($Argument -notmatch '[\s"]') { return $Argument }

 return '"' + ($Argument -replace '"', '\"') + '"'
}

function Invoke-NativeCaptured {
 param(
     [string]$FilePath,
     [string[]]$ArgumentList,
     [string]$WorkingDirectory = $script:Root
 )

 $base = Join-Path ([System.IO.Path]::GetTempPath()) ("victim-matrix-native-{0}" -f ([guid]::NewGuid().ToString('N')))
 $stdoutFile = "$base.out"
 $stderrFile = "$base.err"
 try {
     $quotedArgs = ($ArgumentList | ForEach-Object { Quote-NativeArgument $_ }) -join ' '
     $process = Start-Process -FilePath $FilePath -ArgumentList $quotedArgs -WorkingDirectory $WorkingDirectory -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -NoNewWindow -Wait -PassThru
     $output = @()
     if (Test-Path -LiteralPath $stdoutFile) { $output += Get-Content -LiteralPath $stdoutFile -ErrorAction SilentlyContinue }
     if (Test-Path -LiteralPath $stderrFile) { $output += Get-Content -LiteralPath $stderrFile -ErrorAction SilentlyContinue }
     return [pscustomobject]@{
         Output = $output
         ExitCode = $process.ExitCode
     }
 }
 finally {
     Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
 }
}

function Build-PlatformTarget {
 param($Config, $TargetId, $TargetDir)

 $srcDir = Join-Path $script:Root $TargetDir
 $outSub = Join-Path $OutDir $Config.Name
 $hostPlatform = Get-HostPlatformName
 $linuxCcArg = if ($Config.Arch -eq 'x86') { 'CC=cc -m32' } else { 'CC=cc -m64' }

 New-Item -ItemType Directory -Force -Path $outSub | Out-Null

 $exitCode = 0

 switch ($TargetId) {
     '37' {
         $targetOut = Join-Path $outSub 'linux_shared_library'
         if ($Clean -and (Test-Path -LiteralPath $targetOut)) {
             Remove-OutputDirectorySafely -OutputPath $targetOut
         }
         if ($hostPlatform -eq 'windows') {
             if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
                 Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
                 Write-Host "  TARGET: $TargetId ($TargetDir) [Linux shared library]" -ForegroundColor Yellow
                 Write-Host "  CONFIG: $($Config.Name)  |  SKIP (WSL is not available)" -ForegroundColor DarkYellow
                 Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
                 return $true
             }
             $wslSrc = ConvertTo-WslPath -Path $srcDir
             $wslOut = ConvertTo-WslPath -Path $targetOut
             $captured = Invoke-NativeCaptured -FilePath 'wsl.exe' -ArgumentList @('make', '-C', $wslSrc, "OUT=$wslOut", $linuxCcArg, 'all')
             $result = $captured.Output
             $exitCode = $captured.ExitCode
         }
         elseif ($hostPlatform -ne 'linux') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Linux shared library]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires Linux host)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         else {
             $result = & make -C $srcDir "OUT=$targetOut" $linuxCcArg all 2>&1
             $exitCode = $LASTEXITCODE
         }
     }
     '38' {
         if ($hostPlatform -ne 'macos') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [macOS shared library]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires macOS host)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $targetOut = Join-Path $outSub 'macos_shared_library'
         $result = & make -C $srcDir "OUT=$targetOut" all 2>&1
     }
     '39' {
         $targetOut = Join-Path $outSub 'linux_cli_app'
         if ($Clean -and (Test-Path -LiteralPath $targetOut)) {
             Remove-OutputDirectorySafely -OutputPath $targetOut
         }
         if ($hostPlatform -eq 'windows') {
             if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
                 Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
                 Write-Host "  TARGET: $TargetId ($TargetDir) [Linux CLI]" -ForegroundColor Yellow
                 Write-Host "  CONFIG: $($Config.Name)  |  SKIP (WSL is not available)" -ForegroundColor DarkYellow
                 Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
                 return $true
             }
             $wslSrc = ConvertTo-WslPath -Path $srcDir
             $wslOut = ConvertTo-WslPath -Path $targetOut
             $captured = Invoke-NativeCaptured -FilePath 'wsl.exe' -ArgumentList @('make', '-C', $wslSrc, "OUT=$wslOut", $linuxCcArg, 'all')
             $result = $captured.Output
             $exitCode = $captured.ExitCode
         }
         elseif ($hostPlatform -ne 'linux') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [Linux CLI]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires Linux host)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         else {
             $result = & make -C $srcDir "OUT=$targetOut" $linuxCcArg all 2>&1
             $exitCode = $LASTEXITCODE
         }
     }
     '40' {
         if ($hostPlatform -ne 'macos') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [macOS CLI]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires macOS host)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $targetOut = Join-Path $outSub 'macos_cli_app'
         $result = & sh (Join-Path $srcDir 'build.sh') $targetOut 2>&1
     }
     '41' {
         if ($hostPlatform -ne 'macos') {
             Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
             Write-Host "  TARGET: $TargetId ($TargetDir) [macOS UI]" -ForegroundColor Yellow
             Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires macOS host)" -ForegroundColor DarkYellow
             Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
             return $true
         }
         $targetOut = Join-Path $outSub 'macos_ui_app'
         $result = & sh (Join-Path $srcDir 'build.sh') $targetOut 2>&1
     }
 }

 if ($exitCode -ne 0) {
     Write-Host "  [FAIL] platform build" -ForegroundColor Red
     Write-Host ($result -join "`n")
     return $false
 }

 $artifacts = Get-ChildItem -Path $outSub -Recurse -Include *.so,*.dylib,*.exe,linux_cli_app,macos_cli_app,*.app 2>$null
 if ($artifacts) {
     Write-Host "  [OK]   artifacts:" -ForegroundColor Green
     foreach ($a in $artifacts) {
         $size = if ($a.PSIsContainer) { '<dir>' } else { '{0,8:N0} KB' -f ($a.Length / 1KB) }
         Write-Host "         $($a.Name)  $size" -ForegroundColor Green
     }
 }
return $true
}

function Build-ScriptTarget {
 param($Config, $TargetId, $TargetDir)

 $srcDir = Join-Path $script:Root $TargetDir
 $outBase = Join-Path $OutDir $Config.Name
 $outSub = Join-Path $outBase $TargetDir
 $hostPlatform = Get-HostPlatformName
 $arch = if ($Config.Arch -eq 'x86') { 'x86' } else { 'x64' }
 $scriptArch = if (@('55', '56', '57') -contains $TargetId) { 'x86' } else { $arch }
 $vsCfg = if ($Config.Name -like '*Debug*') { 'Debug' } else { 'Release' }

 $linuxOnly = @('45', '48', '53', '54', '61', '63')
 $macOnly = @('46', '47', '50', '51', '52', '60', '64')
 $windowsOnly = @('44', '49', '55', '56', '57', '58', '59', '62', '65', '66')
 $runLinuxViaWsl = (($linuxOnly -contains $TargetId) -and $hostPlatform -eq 'windows')

 if (($linuxOnly -contains $TargetId) -and $hostPlatform -ne 'linux' -and -not $runLinuxViaWsl) {
     Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host "  TARGET: $TargetId ($TargetDir) [scripted]" -ForegroundColor Yellow
     Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires Linux host)" -ForegroundColor DarkYellow
     Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
     return $true
 }
 if (($macOnly -contains $TargetId) -and $hostPlatform -ne 'macos') {
     Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host "  TARGET: $TargetId ($TargetDir) [scripted]" -ForegroundColor Yellow
     Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires macOS host)" -ForegroundColor DarkYellow
     Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
     return $true
 }
 if (($windowsOnly -contains $TargetId) -and $hostPlatform -ne 'windows') {
     Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
     Write-Host "  TARGET: $TargetId ($TargetDir) [scripted]" -ForegroundColor Yellow
     Write-Host "  CONFIG: $($Config.Name)  |  SKIP (requires Windows host)" -ForegroundColor DarkYellow
     Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
     return $true
 }

 New-Item -ItemType Directory -Force -Path $outSub | Out-Null

 Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
 Write-Host "  TARGET: $TargetId ($TargetDir) [scripted]" -ForegroundColor Yellow
 Write-Host "  CONFIG: $($Config.Name)  |  ARCH: $scriptArch" -ForegroundColor Yellow
 Write-Host "  OUT:    $outSub" -ForegroundColor DarkYellow
 Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

 $psScript = Join-Path $srcDir 'build.ps1'
 $shScript = Join-Path $srcDir 'build.sh'
 $makefile = Join-Path $srcDir 'Makefile'

 if (-not (Test-Path -LiteralPath $psScript) -and -not (Test-Path -LiteralPath $shScript) -and -not (Test-Path -LiteralPath $makefile)) {
     Write-Host "  [FAIL] No build.ps1, build.sh, or Makefile found in $srcDir" -ForegroundColor Red
     return $false
 }

 if ($NoBuild) {
     $availability = if ($runLinuxViaWsl) { 'script target available via WSL (--no-build)' } else { 'script target available (--no-build)' }
     Write-Host "  [OK]   $availability" -ForegroundColor Green
     return $true
 }

 $exitCode = 0

 if ($runLinuxViaWsl) {
     if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
         Write-Host "  SKIP: WSL is not available on this Windows host." -ForegroundColor DarkYellow
         return $true
     }
     $wslOut = ConvertTo-WslPath -Path $outSub
     if (Test-Path -LiteralPath $shScript) {
         $wslScript = ConvertTo-WslPath -Path $shScript
         $captured = Invoke-NativeCaptured -FilePath 'wsl.exe' -ArgumentList @('bash', $wslScript, $wslOut, $scriptArch, $Config.Name)
         $result = $captured.Output
         $exitCode = $captured.ExitCode
     }
     elseif (Test-Path -LiteralPath $makefile) {
         $wslSrc = ConvertTo-WslPath -Path $srcDir
         $captured = Invoke-NativeCaptured -FilePath 'wsl.exe' -ArgumentList @('make', '-C', $wslSrc, "OUT=$wslOut", 'all')
         $result = $captured.Output
         $exitCode = $captured.ExitCode
     }
     else {
         Write-Host "  [FAIL] Linux target has no build.sh or Makefile for WSL dispatch." -ForegroundColor Red
         return $false
     }
 }
 elseif (Test-Path -LiteralPath $psScript) {
     if ($windowsOnly -contains $TargetId) {
         Ensure-VSEnv -Arch $scriptArch
     }
     $scriptArgs = @(
         '-NoProfile',
         '-ExecutionPolicy', 'Bypass',
         '-File', $psScript,
         '-Arch', $scriptArch,
         '-Configuration', $vsCfg,
         '-OutDir', $outSub,
         '-SkipIfUnavailable'
     )
     if ($Clean) { $scriptArgs += '-Clean' }
     $result = & powershell @scriptArgs 2>&1
     $exitCode = $LASTEXITCODE
 }
 elseif (Test-Path -LiteralPath $shScript) {
     $result = & sh $shScript $outSub $scriptArch $Config.Name 2>&1
     $exitCode = $LASTEXITCODE
 }
 elseif (Test-Path -LiteralPath $makefile) {
     $result = & make -C $srcDir "OUT=$outSub" all 2>&1
     $exitCode = $LASTEXITCODE
 }

 Write-Host ($result -join "`n")
 if ($exitCode -ne 0) {
     Write-Host "  [FAIL] scripted target build failed" -ForegroundColor Red
     return $false
 }

 $artifactExts = [System.Collections.Generic.HashSet[string]]@('.exe', '.dll', '.efi', '.map', '.pdb', '.so', '.dylib', '.ko')
 $artifacts = Get-ChildItem -Path $outSub -Recurse -ErrorAction SilentlyContinue | Where-Object {
     ($_.PSIsContainer -and $_.Extension -eq '.app') -or
     ((-not $_.PSIsContainer) -and ($artifactExts.Contains($_.Extension) -or ([string]::IsNullOrEmpty($_.Extension) -and $_.Name -match '^(linux_|macos_|gcc_|msvc_|ios_|delphi_|win32_)')))
 }
 if ($artifacts) {
     Write-Host "  [OK]   artifacts:" -ForegroundColor Green
     foreach ($a in $artifacts) {
         $size = if ($a.PSIsContainer) { '<dir>' } else { '{0,8:N0} KB' -f ($a.Length / 1KB) }
         Write-Host "         $($a.Name)  $size" -ForegroundColor Green
     }
 }
 return $true
}

function Build-LlvmLitTarget {
 param($Config, $TargetId, $TargetDir)

 $srcDir = Join-Path $script:Root $TargetDir
 $outSub = Join-Path $OutDir $Config.Name
 $llvmProjectDir = $DefaultLlvmProjectDir
 $llvmBuildDir = $DefaultLlvmBuildDir

 Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
 Write-Host "  TARGET: $TargetId ($TargetDir) [LLVM LIT binaries]" -ForegroundColor Yellow
 Write-Host "  CONFIG: $($Config.Name)" -ForegroundColor Yellow
 Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

 if ([string]::IsNullOrWhiteSpace($llvmProjectDir) -or [string]::IsNullOrWhiteSpace($llvmBuildDir) -or
     -not (Test-Path -LiteralPath $llvmProjectDir) -or -not (Test-Path -LiteralPath $llvmBuildDir)) {
     Write-Host "  SKIP: set LLVM_PROJECT_DIR and LLVM_BUILD_DIR to existing LLVM source/build directories." -ForegroundColor DarkYellow
     return $true
 }

 New-Item -ItemType Directory -Force -Path $outSub | Out-Null
 $zipPath = Join-Path $outSub 'original-llvm-lit-binaries.zip'
 $scriptPath = Join-Path $srcDir 'prepare_llvm_lit_binaries.ps1'
 $result = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -LLVMProjectDir $llvmProjectDir -BuildDir $llvmBuildDir -OutputZip $zipPath 2>&1

 if ($LASTEXITCODE -ne 0) {
     Write-Host "  [FAIL] LLVM LIT binary pack" -ForegroundColor Red
     Write-Host ($result -join "`n")
     return $false
 }

 Write-Host ($result -join "`n")
 if (Test-Path $zipPath) {
     $zip = Get-Item $zipPath
     $size = '{0,8:N0} KB' -f ($zip.Length / 1KB)
     Write-Host "  [OK]   $($zip.Name)  $size" -ForegroundColor Green
 }
 return $true
}

# ── Main ─────────────────────────────────────────────────────────────────────
$startTime = Get-Date
$total = 0
foreach ($cfg in $selectedConfigs) {
    foreach ($tgt in $selectedTargets) {
        if (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key) {
            $total++
        }
    }
}
if ($total -eq 0) {
    Write-Error "No applicable config/target pairs selected."
    exit 1
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Victim Matrix Build" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ("  Configs : {0}" -f ($selectedConfigs.Name -join ', '))
Write-Host ("  Targets : {0}" -f (($selectedTargets | ForEach-Object { $_.Key }) -join ', '))
Write-Host ("  Total   : {0} applicable config-target pairs" -f $total)
Write-Host "================================================================" -ForegroundColor Cyan

$succeeded = 0
$failed    = 0

# Split targets into C++, MSBuild (vcxproj), .NET, native toolchains, GUI app packagers, platform-native targets, scripted targets, and LLVM LIT packs
$cppTargets     = $selectedTargets | Where-Object { -not $DotNetTargets.Contains($_.Key) -and -not $MSBuildTargets.Contains($_.Key) -and -not $NativeTargets.Contains($_.Key) -and -not $GuiAppTargets.Contains($_.Key) -and -not $PlatformTargets.Contains($_.Key) -and -not $ScriptTargets.Contains($_.Key) -and -not $LlvmLitTargets.Contains($_.Key) }
$msbuildTargets = $selectedTargets | Where-Object { $MSBuildTargets.Contains($_.Key) }
$dotnetTargets  = $selectedTargets | Where-Object { $DotNetTargets.Contains($_.Key) }
$nativeTargets  = $selectedTargets | Where-Object { $NativeTargets.Contains($_.Key) }
$guiAppTargets  = $selectedTargets | Where-Object { $GuiAppTargets.Contains($_.Key) }
$platformTargets = $selectedTargets | Where-Object { $PlatformTargets.Contains($_.Key) }
$scriptTargets = $selectedTargets | Where-Object { $ScriptTargets.Contains($_.Key) }
$llvmLitTargets = $selectedTargets | Where-Object { $LlvmLitTargets.Contains($_.Key) }
# ── C++ targets (need vcvars per arch) ───────────────────────────────────────
if ($cppTargets) {
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $cppTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            if (Test-ConfigRequiresVSEnv $cfg) { Ensure-VSEnv -Arch $cfg.Arch }
            $ok = Build-Target -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# ── .NET targets (dotnet has its own toolchain) ──────────────────────────────
if ($dotnetTargets) {
    Write-Host "`n>>> Building .NET targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $dotnetTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-DotNetTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# ── MSBuild vcxproj targets ───────────────────────────────────────────
if ($msbuildTargets) {
    Write-Host "`n>>> Building MSBuild vcxproj targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $msbuildTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-MSBuildTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# ── Native toolchain targets (Rust, Go, Odin, Zig, raw PE) ─────────────────
if ($nativeTargets) {
    Write-Host "`n>>> Building native toolchain targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $nativeTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-NativeTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# â”€â”€ GUI app packagers (Python, Node.js, Electron, Tauri, Flutter, Java) â”€â”€â”€â”€
if ($guiAppTargets) {
    Write-Host "`n>>> Building GUI app package targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $guiAppTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-GuiAppTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# â”€â”€ Platform-native targets (Linux/macOS-only builds) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if ($platformTargets) {
    Write-Host "`n>>> Building platform-native targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $platformTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-PlatformTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# Scripted targets (Delphi/map/cross-platform architecture variants)
if ($scriptTargets) {
    Write-Host "`n>>> Building scripted targets..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $scriptTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-ScriptTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}

# LLVM LIT binary packs (requires external llvm-project build)
if ($llvmLitTargets) {
    Write-Host "`n>>> Preparing LLVM LIT binary packs..." -ForegroundColor Blue
    foreach ($cfg in $selectedConfigs) {
        foreach ($tgt in $llvmLitTargets) {
            if (-not (Test-ConfigAppliesToTarget -Config $cfg -TargetId $tgt.Key)) {
                continue
            }
            $ok = Build-LlvmLitTarget -Config $cfg -TargetId $tgt.Key -TargetDir $tgt.Value
            if ($ok) { $succeeded++ } else { $failed++ }
        }
    }
}
$elapsed = (Get-Date) - $startTime
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host ("  BUILD COMPLETE  --  {0} succeeded, {1} failed, {2} total" -f $succeeded, $failed, $total) -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host ("  Elapsed: {0:hh\:mm\:ss}" -f $elapsed)
Write-Host ("  Output:  $OutDir")
Write-Host "================================================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
