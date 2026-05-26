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

function Get-PeMachineType {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 0x40) {
            throw "PE image is too small: $Path"
        }

        $reader = [System.IO.BinaryReader]::new($stream)
        $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 0 -or ($peOffset + 6) -gt $stream.Length) {
            throw "PE header offset is invalid: $Path"
        }

        $stream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $signature = $reader.ReadUInt32()
        if ($signature -ne 0x00004550) {
            throw "PE signature is invalid: $Path"
        }

        return $reader.ReadUInt16()
    }
    finally {
        $stream.Dispose()
    }
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
$expectedMachine = if ($Arch -eq 'x86') { 0x014c } else { 0x8664 }
$expectedMachineName = if ($Arch -eq 'x86') { 'IA32' } else { 'X64' }
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
$output = $stdout + $stderr
if ($exitCode -eq 0) {
    $output = $output | Where-Object {
        $_ -notmatch '^!!! ERROR !!! Cannot find BaseTools Bin Win32!!!$' -and
        $_ -notmatch '^Please check the directory\s*$' -and
        $_ -notmatch '^Or configure EDK_TOOLS_BIN env to point to Bin directory\.$'
    }
}
Write-Host ($output -join "`n")
if ($exitCode -ne 0) { exit $exitCode }

$buildArchRoot = Join-Path $edkWorkspace "Build\UefiVictimPkg\$($target)_$toolchain\$archName"
$efiFile = Join-Path $buildArchRoot 'UefiVictim.efi'
if (-not (Test-Path -LiteralPath $efiFile)) {
    $efiFile = Get-ChildItem -LiteralPath $buildArchRoot -Recurse -Filter UefiVictim.efi -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -ExpandProperty FullName -First 1
}

if (-not $efiFile -or -not (Test-Path -LiteralPath $efiFile)) {
    throw "UEFI build completed but did not produce $expectedMachineName artifact under $buildArchRoot"
}

$machine = Get-PeMachineType -Path $efiFile
if ($machine -ne $expectedMachine) {
    throw ("UEFI build produced wrong machine type 0x{0:X4}; expected {1} for {2}" -f $machine, $expectedMachineName, $Arch)
}

$destination = Join-Path $OutDir 'UefiVictim.efi'
Copy-Item -LiteralPath $efiFile -Destination $destination -Force

Write-Host "OK: UEFI driver build complete ($expectedMachineName)"
