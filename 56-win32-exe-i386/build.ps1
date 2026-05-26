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

$exe = Join-Path $OutDir 'win32_exe_i386.exe'
$obj = Join-Path $OutDir 'win32_exe_i386.obj'
$pdb = Join-Path $OutDir 'win32_exe_i386.pdb'
if ($Clean) {
    foreach ($path in @($exe, $obj, $pdb)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

$cflags = if ($Configuration -eq 'Debug') { @('/Zi', '/Od', '/GS') } else { @('/O2', '/GS', '/sdl') }
$args = @('/nologo', '/W4') + $cflags + @("/Fo$obj", "/Fd$pdb", "/Fe$exe", (Join-Path $Root 'main.c'), '/link', '/MACHINE:X86', '/DYNAMICBASE', '/NXCOMPAT')
$result = & cl.exe @args 2>&1
Write-Host ($result -join "`n")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "OK: $exe"
