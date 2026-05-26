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
    $message = 'SKIP: cl.exe not found. Run from a Visual Studio developer shell.'
    if ($SkipIfUnavailable) { Write-Host $message; exit 0 }
    throw $message
}

if ($Clean) {
    foreach ($name in @('msvc_debug_map', 'msvc_release_cf_map', 'msvc_ltcg_hardened_map')) {
        $dir = Join-Path $OutDir $name
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
    }
}

$source = Join-Path $Root 'main.c'
$machine = if ($Arch -eq 'x86') { 'X86' } else { 'X64' }
$variants = @(
    [pscustomobject]@{
        Id = 1
        Name = 'msvc_debug_map'
        CFlags = @('/Zi', '/Od', '/GS', '/RTC1')
        LFlags = @('/DEBUG', '/INCREMENTAL:NO')
    },
    [pscustomobject]@{
        Id = 2
        Name = 'msvc_release_cf_map'
        CFlags = @('/O2', '/GS', '/guard:cf', '/sdl')
        LFlags = @('/DEBUG', '/INCREMENTAL:NO', '/DYNAMICBASE', '/NXCOMPAT', '/GUARD:CF')
    },
    [pscustomobject]@{
        Id = 3
        Name = 'msvc_ltcg_hardened_map'
        CFlags = @('/O2', '/GL', '/GS', '/guard:cf', '/sdl')
        LFlags = @('/LTCG', '/DEBUG', '/INCREMENTAL:NO', '/DYNAMICBASE', '/NXCOMPAT', '/GUARD:CF')
    }
)

foreach ($variant in $variants) {
    $variantOut = Join-Path $OutDir $variant.Name
    New-Item -ItemType Directory -Force -Path $variantOut | Out-Null
    $obj = Join-Path $variantOut "$($variant.Name).obj"
    $pdb = Join-Path $variantOut "$($variant.Name).pdb"
    $exe = Join-Path $variantOut "$($variant.Name).exe"
    $map = Join-Path $variantOut "$($variant.Name).map"
    $define = "/DVICTIM_VARIANT_ID=$($variant.Id)"

    Write-Host "BUILD: $($variant.Name) [$Arch]"
    $args = @('/nologo', '/W4', $define) + $variant.CFlags + @("/Fo$obj", "/Fd$pdb", "/Fe$exe", $source, '/link') + $variant.LFlags + @("/MACHINE:$machine", "/MAP:$map")
    $result = & cl.exe @args 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host 'OK: MSVC MAP hardened variants built'
