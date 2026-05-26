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

function Get-Edk2Workspace {
    if ($env:EDK2_WORKSPACE -and (Test-Path -LiteralPath (Join-Path $env:EDK2_WORKSPACE 'edksetup.bat'))) {
        return $env:EDK2_WORKSPACE
    }
    if ($env:WORKSPACE -and (Test-Path -LiteralPath (Join-Path $env:WORKSPACE 'edksetup.bat'))) {
        return $env:WORKSPACE
    }
    $default = Join-Path $env:USERPROFILE 'Tools\edk2'
    if (Test-Path -LiteralPath (Join-Path $default 'edksetup.bat')) {
        return $default
    }
    return ''
}

$edkWorkspace = Get-Edk2Workspace
if ([string]::IsNullOrWhiteSpace($edkWorkspace)) {
    Copy-Item -LiteralPath (Join-Path $Root 'UefiVictim.c') -Destination $OutDir -Force
    Copy-Item -LiteralPath (Join-Path $Root 'UefiVictim.inf') -Destination $OutDir -Force
    $message = 'SKIP: EDK II workspace was not found; copied module sources instead.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

$archName = if ($Arch -eq 'x86') { 'IA32' } else { 'X64' }
$target = if ($Configuration -eq 'Debug') { 'DEBUG' } else { 'RELEASE' }
$toolchain = if (Test-Path -LiteralPath "${env:ProgramFiles}\Microsoft Visual Studio\18") { 'VS2026' } else { 'VS2022' }
$nasmPrefix = if (Test-Path -LiteralPath 'C:\Program Files\NASM\nasm.exe') { 'C:\Program Files\NASM\' } else { $env:NASM_PREFIX }
$iaslPrefix = if (Test-Path -LiteralPath 'C:\ProgramData\chocolatey\bin\iasl.exe') { 'C:\ProgramData\chocolatey\bin\' } else { $env:IASL_PREFIX }
$packageRoot = Join-Path $edkWorkspace 'VictimPkg'
$moduleRoot = Join-Path $packageRoot 'UefiVictim'
New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $Root 'UefiVictim.c') -Destination $moduleRoot -Force
Copy-Item -LiteralPath (Join-Path $Root 'UefiVictim.inf') -Destination $moduleRoot -Force
Copy-Item -LiteralPath (Join-Path $Root 'UefiVictim.dsc') -Destination $packageRoot -Force

$cmdFile = Join-Path $OutDir 'build-uefi.cmd'
$stdoutFile = Join-Path $OutDir 'build-uefi.stdout.log'
$stderrFile = Join-Path $OutDir 'build-uefi.stderr.log'
$buildCommand = @"
@echo off
set "NASM_PREFIX=$nasmPrefix"
set "IASL_PREFIX=$iaslPrefix"
cd /d "$edkWorkspace"
call edksetup.bat $toolchain
build -p "VictimPkg\UefiVictim.dsc" -a $archName -b $target -t $toolchain -m "VictimPkg\UefiVictim\UefiVictim.inf"
"@
$buildCommand | Set-Content -LiteralPath $cmdFile -Encoding ASCII
$process = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/s', '/c', "`"$cmdFile`"") -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -NoNewWindow -Wait -PassThru
$exitCode = $process.ExitCode
$stdout = if (Test-Path -LiteralPath $stdoutFile) { Get-Content -LiteralPath $stdoutFile -ErrorAction SilentlyContinue } else { @() }
$stderr = if (Test-Path -LiteralPath $stderrFile) { Get-Content -LiteralPath $stderrFile -ErrorAction SilentlyContinue } else { @() }
Write-Host (($stdout + $stderr) -join "`n")
if ($exitCode -ne 0) { exit $exitCode }

$efiFiles = Get-ChildItem -LiteralPath $edkWorkspace -Recurse -Filter UefiVictim.efi -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($efiFiles) {
    Copy-Item -LiteralPath $efiFiles[0].FullName -Destination (Join-Path $OutDir 'UefiVictim.efi') -Force
}

Write-Host 'OK: UEFI driver build complete'
