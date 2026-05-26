[CmdletBinding()]
param(
    [ValidateSet('x86', 'x64')]
    [string]$Arch = 'x64',

    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [string]$OutDir = '',

    [switch]$Clean,
    [switch]$SkipIfUnavailable
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSCommandPath
if ($OutDir -eq '') { $OutDir = Join-Path $Root 'bin' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Import-VSEnvIfAvailable {
    param([string]$RequestedArch)
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return $true }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsPath = if (Test-Path -LiteralPath $vswhere) { & $vswhere -latest -property installationPath 2>$null } else { '' }
    if ([string]::IsNullOrWhiteSpace($vsPath)) {
        $vsPath = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Enterprise",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise"
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if ([string]::IsNullOrWhiteSpace($vsPath)) { return $false }
    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { return $false }
    $archArg = if ($RequestedArch -eq 'x86') { 'x86' } else { 'amd64' }
    $envBlock = cmd /s /c "`"$vcvars`" $archArg >NUL 2>&1 && set"
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($line in $envBlock) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
    return [bool](Get-Command cl.exe -ErrorAction SilentlyContinue)
}

function Get-WdkRoot {
    foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots')) {
        if (Test-Path -LiteralPath $key) {
            $root = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).KitsRoot10
            if ($root -and (Test-Path -LiteralPath $root)) { return $root }
        }
    }
    return ''
}

if (-not (Import-VSEnvIfAvailable -RequestedArch $Arch)) {
    $message = 'SKIP: cl.exe not found. Install Visual Studio Build Tools.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

$wdkRoot = Get-WdkRoot
if ([string]::IsNullOrWhiteSpace($wdkRoot)) {
    $message = 'SKIP: Windows Driver Kit root was not found.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

$includeVersion = Get-ChildItem -LiteralPath (Join-Path $wdkRoot 'Include') -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'km\ntddk.h') } |
    Select-Object -First 1
if (-not $includeVersion) {
    $message = 'SKIP: WDK kernel headers were not found.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

if ($Clean) { Get-ChildItem -LiteralPath $OutDir -Filter 'driver_runtime_module.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force }

$obj = Join-Path $OutDir 'driver_runtime_module.obj'
$lib = Join-Path $OutDir 'driver_runtime_module.lib'
$flags = if ($Configuration -eq 'Debug') { @('/Zi', '/Od', '/GS') } else { @('/O2', '/GS', '/sdl', '/guard:cf', '/Qspectre') }
$archDefines = if ($Arch -eq 'x86') { @('/D_X86_=1', '/Di386=1') } else { @('/D_AMD64_=1', '/DAMD64=1') }
$args = @('/nologo', '/W4', '/WX-', '/c') + $archDefines + $flags + @("/I$(Join-Path $includeVersion.FullName 'km')", "/I$(Join-Path $includeVersion.FullName 'shared')", "/Fo$obj", (Join-Path $Root 'driver_runtime_module.c'))
$compile = & cl.exe @args 2>&1
Write-Host ($compile -join "`n")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$libExe = Get-Command lib.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($libExe) {
    $result = & lib.exe /nologo "/OUT:$lib" $obj 2>&1
    Write-Host ($result -join "`n")
}

Write-Host "OK: $obj"
