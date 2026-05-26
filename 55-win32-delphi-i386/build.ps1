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

foreach ($name in @('Win32DelphiVictim.exe', 'win32_delphi_i386.exe')) {
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
$project = Join-Path $Root 'Win32DelphiVictim.dpr'

Write-Host "Win32 Delphi i386 victim"
Write-Host "  Arch request : $Arch (emits i386)"
Write-Host "  Config       : $Configuration"
Write-Host "  Output       : $OutDir"

if ([string]::IsNullOrWhiteSpace($dcc32) -and [string]::IsNullOrWhiteSpace($fpc)) {
    $message = 'SKIP: dcc32.exe or fpc.exe was not found.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

if (-not [string]::IsNullOrWhiteSpace($dcc32)) {
    $result = & $dcc32 -B -Q "-E$OutDir" $project 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $dccExe = Join-Path $OutDir 'Win32DelphiVictim.exe'
    if (-not (Test-Path -LiteralPath $dccExe)) {
        $message = 'SKIP: Delphi is installed, but this edition/license did not produce command-line compiler output.'
        if ($result -match 'does not support command line compiling') {
            $message = 'SKIP: Delphi is installed, but this edition/license does not support command-line compiling.'
        }
        if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
        throw $message
    }
    if (Test-Path -LiteralPath $dccExe) {
        Copy-Item -LiteralPath $dccExe -Destination (Join-Path $OutDir 'win32_delphi_i386.exe') -Force
    }
} else {
    $exe = Join-Path $OutDir 'win32_delphi_i386.exe'
    $args = @('-Mdelphi', '-Twin32', '-Pi386', '-O2', "-FE$OutDir", "-o$exe", $project)
    $result = & $fpc @args 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath $exe)) {
        $message = 'SKIP: Free Pascal completed without producing win32_delphi_i386.exe.'
        if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
        throw $message
    }
}

Write-Host 'OK: Win32 Delphi i386 build complete'
