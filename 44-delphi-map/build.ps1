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

foreach ($name in @('DelphiMapVictim.exe', 'DelphiMapVictim.map', 'delphi_map_victim.exe', 'delphi_map_victim.map')) {
    $path = Join-Path $OutDir $name
    if ($Clean -and (Test-Path -LiteralPath $path)) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Find-Tool {
    param([string]$EnvName, [string]$Name)
    $envValue = [Environment]::GetEnvironmentVariable($EnvName)
    if (-not [string]::IsNullOrWhiteSpace($envValue) -and (Test-Path -LiteralPath $envValue)) {
        return $envValue
    }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return ''
}

$dcc32 = Find-Tool -EnvName 'DELPHI_DCC32' -Name 'dcc32.exe'
$fpc = Find-Tool -EnvName 'FPC' -Name 'fpc.exe'
$project = Join-Path $Root 'DelphiMapVictim.dpr'

Write-Host "Delphi MAP victim"
Write-Host "  Arch request : $Arch"
Write-Host "  Config       : $Configuration"
Write-Host "  Output       : $OutDir"

if ([string]::IsNullOrWhiteSpace($dcc32) -and [string]::IsNullOrWhiteSpace($fpc)) {
    $message = 'SKIP: dcc32.exe or fpc.exe was not found.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

if (-not [string]::IsNullOrWhiteSpace($dcc32)) {
    if ($Arch -ne 'x86') {
        Write-Host 'SKIP: dcc32 emits Win32/i386 output for this sample.'
        exit 0
    }
    $result = & $dcc32 -B -Q -GD "-E$OutDir" $project 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $dccExe = Join-Path $OutDir 'DelphiMapVictim.exe'
    if (-not (Test-Path -LiteralPath $dccExe)) {
        $message = 'SKIP: Delphi is installed, but this edition/license did not produce command-line compiler output.'
        if ($result -match 'does not support command line compiling') {
            $message = 'SKIP: Delphi is installed, but this edition/license does not support command-line compiling.'
        }
        if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
        throw $message
    }
} else {
    $osTarget = if ($Arch -eq 'x86') { 'Win32' } else { 'Win64' }
    $cpuTarget = if ($Arch -eq 'x86') { 'i386' } else { 'x86_64' }
    $exe = Join-Path $OutDir 'delphi_map_victim.exe'
    $args = @('-Mdelphi', "-T$osTarget", "-P$cpuTarget", '-O2', '-gl', '-Xm', "-FE$OutDir", "-o$exe", $project)
    $result = & $fpc @args 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath $exe)) {
        $message = 'SKIP: Free Pascal completed without producing delphi_map_victim.exe.'
        if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
        throw $message
    }
}

$dccExe = Join-Path $OutDir 'DelphiMapVictim.exe'
$dccMap = Join-Path $OutDir 'DelphiMapVictim.map'
if (Test-Path -LiteralPath $dccExe) {
    Copy-Item -LiteralPath $dccExe -Destination (Join-Path $OutDir 'delphi_map_victim.exe') -Force
}
if (Test-Path -LiteralPath $dccMap) {
    Copy-Item -LiteralPath $dccMap -Destination (Join-Path $OutDir 'delphi_map_victim.map') -Force
}

Write-Host 'OK: Delphi MAP build complete'
