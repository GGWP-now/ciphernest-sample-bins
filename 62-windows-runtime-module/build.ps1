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

if (-not (Import-VSEnvIfAvailable -RequestedArch $Arch)) {
    $message = 'SKIP: cl.exe not found. Install Visual Studio Build Tools.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

$dll = Join-Path $OutDir 'windows_runtime_module.dll'
$pdb = Join-Path $OutDir 'windows_runtime_module.pdb'
if ($Clean) {
    Get-ChildItem -LiteralPath $OutDir -Filter 'windows_runtime_module.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force
}

$machine = if ($Arch -eq 'x86') { 'X86' } else { 'X64' }
$flags = if ($Configuration -eq 'Debug') { @('/Zi', '/Od', '/GS') } else { @('/O2', '/GS', '/sdl', '/guard:cf') }
$args = @('/nologo', '/W4', '/LD') + $flags + @("/Fd$pdb", "/Fe$dll", (Join-Path $Root 'runtime_module.c'), '/link', "/MACHINE:$machine", '/DYNAMICBASE', '/NXCOMPAT', '/GUARD:CF')
$result = & cl.exe @args 2>&1
Write-Host ($result -join "`n")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "OK: $dll"
