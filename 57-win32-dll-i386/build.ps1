[CmdletBinding()]
param(
    [ValidateSet('x86', 'x64')]
    [string]$Arch = 'x86',

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
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return $true }

    $vsPath = ''
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $vsPath = & $vswhere -latest -property installationPath 2>$null
    }
    if ([string]::IsNullOrWhiteSpace($vsPath)) {
        $candidates = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Enterprise",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise"
        )
        $vsPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if ([string]::IsNullOrWhiteSpace($vsPath)) { return $false }

    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { return $false }

    $envBlock = cmd /s /c "`"$vcvars`" x86 >NUL 2>&1 && set"
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($line in $envBlock) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
    return [bool](Get-Command cl.exe -ErrorAction SilentlyContinue)
}

if (-not (Import-VSEnvIfAvailable)) {
    $message = 'SKIP: cl.exe not found. Run from a Visual Studio x86 developer shell.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

if ($Clean) {
    foreach ($pattern in @('win32_dll_i386.*', 'win32_dll_i386_smoke.*')) {
        Get-ChildItem -Path $OutDir -Filter $pattern -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }
}

$cflags = if ($Configuration -eq 'Debug') { @('/Zi', '/Od', '/GS') } else { @('/O2', '/GS', '/sdl') }
$dll = Join-Path $OutDir 'win32_dll_i386.dll'
$implib = Join-Path $OutDir 'win32_dll_i386.lib'
$pdb = Join-Path $OutDir 'win32_dll_i386.pdb'
$dllArgs = @('/nologo', '/W4', '/LD', '/DBUILDING_WIN32_DLL_I386') + $cflags + @("/Fd$pdb", "/Fe$dll", (Join-Path $Root 'win32_dll_i386.c'), '/link', "/IMPLIB:$implib", '/MACHINE:X86', '/DYNAMICBASE', '/NXCOMPAT')
$dllResult = & cl.exe @dllArgs 2>&1
Write-Host ($dllResult -join "`n")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$smoke = Join-Path $OutDir 'win32_dll_i386_smoke.exe'
$smokeArgs = @('/nologo', '/W4') + $cflags + @("/Fe$smoke", (Join-Path $Root 'smoke.c'), $implib, '/link', '/MACHINE:X86', '/DYNAMICBASE', '/NXCOMPAT')
$smokeResult = & cl.exe @smokeArgs 2>&1
Write-Host ($smokeResult -join "`n")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: $dll"
