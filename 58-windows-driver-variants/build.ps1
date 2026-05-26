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

function Get-WdkRoot {
    $registryRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    )
    foreach ($key in $registryRoots) {
        if (Test-Path -LiteralPath $key) {
            $root = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).KitsRoot10
            if ($root -and (Test-Path -LiteralPath $root)) { return $root }
        }
    }
    if ($env:WindowsSdkDir -and (Test-Path -LiteralPath $env:WindowsSdkDir)) { return $env:WindowsSdkDir }
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

$kmInclude = Join-Path $includeVersion.FullName 'km'
$sharedInclude = Join-Path $includeVersion.FullName 'shared'
$umInclude = Join-Path $includeVersion.FullName 'um'
$ucrtInclude = Join-Path $includeVersion.FullName 'ucrt'
$machine = if ($Arch -eq 'x86') { 'X86' } else { 'X64' }
$archDefines = if ($Arch -eq 'x86') { @('/D_X86_=1', '/Di386=1') } else { @('/D_AMD64_=1', '/DAMD64=1') }
$commonFlags = @('/nologo', '/W4', '/WX-', '/c') + $archDefines + @("/D_WIN32_WINNT=0x0A00", "/DNTDDI_VERSION=0x0A000000", "/I$kmInclude", "/I$sharedInclude", "/I$umInclude", "/I$ucrtInclude")
$releaseFlags = if ($Configuration -eq 'Debug') { @('/Zi', '/Od', '/GS') } else { @('/O2', '/GS', '/sdl') }
$variants = @(
    [pscustomobject]@{ Name = 'umdf'; Source = 'variants\umdf\umdf_victim.c'; Extra = @('/DUMDF_VICTIM') },
    [pscustomobject]@{ Name = 'kmdf'; Source = 'variants\kmdf\kmdf_victim.c'; Extra = @('/DKMDF_VICTIM') },
    [pscustomobject]@{ Name = 'ndis'; Source = 'variants\ndis\ndis_victim.c'; Extra = @('/DNDIS_VICTIM') },
    [pscustomobject]@{ Name = 'wdm'; Source = 'variants\wdm\wdm_victim.c'; Extra = @('/DWDM_VICTIM') },
    [pscustomobject]@{ Name = 'simple'; Source = 'variants\simple\simple_driver_victim.c'; Extra = @('/DSIMPLE_DRIVER_VICTIM') },
    [pscustomobject]@{ Name = 'safeguarded'; Source = 'variants\safeguarded\safeguarded_driver_victim.c'; Extra = @('/DSAFEGUARDED_DRIVER_VICTIM', '/guard:cf', '/Qspectre') }
)

if ($Clean -and (Test-Path -LiteralPath $OutDir)) {
    Get-ChildItem -LiteralPath $OutDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
}

foreach ($variant in $variants) {
    $source = Join-Path $Root $variant.Source
    $obj = Join-Path $OutDir "$($variant.Name)_driver_victim.obj"
    Write-Host "BUILD: $($variant.Name) [$Arch compile-only]"
    $args = $commonFlags + $releaseFlags + $variant.Extra + @("/Fo$obj", $source)
    $result = & cl.exe @args 2>&1
    Write-Host ($result -join "`n")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "OK: Windows driver variant objects built for $machine"
