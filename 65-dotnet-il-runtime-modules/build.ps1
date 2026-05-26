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
if ($Clean) { Get-ChildItem -LiteralPath $OutDir -Recurse -File -ErrorAction SilentlyContinue | Remove-Item -Force }

$source = Join-Path $Root 'DotNetRuntimeModule.cs'

function Invoke-Optional {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "BUILD: $Name"
    try {
        & $Action
        Write-Host "OK: $Name"
    } catch {
        Write-Host "SKIP: $Name - $($_.Exception.Message)"
    }
}

Invoke-Optional 'dotnet20' {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v2.0.50727\csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) { throw 'csc.exe v2.0.50727 not found' }
    $dest = Join-Path $OutDir 'DotNetRuntimeModule.net20.dll'
    $result = & $csc /nologo /target:library /optimize+ "/out:$dest" $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
}

Invoke-Optional 'dotnet40' {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) { throw 'csc.exe v4.0.30319 not found' }
    $dest = Join-Path $OutDir 'DotNetRuntimeModule.net40.dll'
    $result = & $csc /nologo /target:library /optimize+ "/out:$dest" $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
}

Invoke-Optional 'ilasm' {
    $ilasm = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\ilasm.exe'
    if (-not (Test-Path -LiteralPath $ilasm)) { throw 'ilasm.exe not found' }
    $dest = Join-Path $OutDir 'ILRuntimeModule.dll'
    $result = & $ilasm /nologo /dll "/output:$dest" (Join-Path $Root 'RuntimeModule.il') 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
}

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dotnet) {
    foreach ($tfm in @('netcoreapp3.1', 'netstandard2.0')) {
        Invoke-Optional $tfm {
            $destDir = Join-Path $OutDir $tfm
            $objBase = Join-Path $OutDir "obj-$tfm"
            $objTfm = Join-Path $objBase $tfm
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            $project = Join-Path $Root 'DotNetRuntimeModules.csproj'
            $result = & dotnet build $project -c Release -f $tfm -o $destDir "/p:BaseIntermediateOutputPath=$objBase\" "/p:IntermediateOutputPath=$objTfm\" 2>&1
            if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
        }
    }
} else {
    Write-Host 'SKIP: netcoreapp3.1/netstandard2.0 - dotnet SDK not found'
}

Write-Host 'OK: .NET/IL runtime module pass complete'
