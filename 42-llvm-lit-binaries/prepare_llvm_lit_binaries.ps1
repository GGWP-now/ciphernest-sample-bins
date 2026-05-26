[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LLVMProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$BuildDir,

    [string]$OutputZip = '',

    [switch]$RunLitSmoke
)

$ErrorActionPreference = 'Stop'

function Resolve-RequiredPath {
    param([string]$Path, [string]$Description)
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "$Description not found: $Path"
    }
    return $resolved.Path
}

function Get-ReleaseBinDir {
    param([string]$BuildDir)
    $candidates = @(
        (Join-Path $BuildDir 'Release\bin'),
        (Join-Path $BuildDir 'bin')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'llvm-lit.py')) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Could not find llvm-lit.py under '$BuildDir\Release\bin' or '$BuildDir\bin'."
}

$LLVMProjectDir = Resolve-RequiredPath $LLVMProjectDir 'LLVM project directory'
$BuildDir = Resolve-RequiredPath $BuildDir 'LLVM build directory'
$binDir = Get-ReleaseBinDir $BuildDir

$clangTest = Resolve-RequiredPath (Join-Path $LLVMProjectDir 'clang\test') 'clang lit test directory'
$lldTest = Resolve-RequiredPath (Join-Path $LLVMProjectDir 'lld\test') 'lld lit test directory'
$llvmLit = Resolve-RequiredPath (Join-Path $binDir 'llvm-lit.py') 'llvm-lit.py'

if ($OutputZip -eq '') {
    $OutputZip = Join-Path (Split-Path -Parent $PSCommandPath) 'original-llvm-lit-binaries.zip'
}
$OutputZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputZip)

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("llvm-lit-bin-pack-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

try {
    $includeExtensions = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    @('.exe', '.dll', '.pdb', '.py', '.bat', '.cmd', '.pyd', '.lib', '.manifest') | ForEach-Object { [void]$includeExtensions.Add($_) }

    $files = Get-ChildItem -LiteralPath $binDir -File | Where-Object {
        $includeExtensions.Contains($_.Extension) -or
        $_.Name -in @('llvm-lit', 'FileCheck', 'not', 'count', 'yaml-bench')
    }

    if (-not $files) {
        throw "No packageable LLVM bin files found in $binDir"
    }

    foreach ($file in $files) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $stagingRoot $file.Name) -Force
    }

    $manifestFiles = foreach ($file in (Get-ChildItem -LiteralPath $stagingRoot -File | Sort-Object Name)) {
        [pscustomobject]@{
            name = $file.Name
            size = $file.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        }
    }

    $manifest = [pscustomobject]@{
        schema = 1
        purpose = 'SigBreaker LLVM LIT clang/lld binary replacement pack'
        llvm_ref = 'llvmorg-20.1.0'
        source_bin = $binDir
        clang_test = $clangTest
        lld_test = $lldTest
        generated_utc = [DateTime]::UtcNow.ToString('o')
        files = $manifestFiles
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stagingRoot '_llvm_lit_binary_manifest.json') -Encoding UTF8

    if (Test-Path -LiteralPath $OutputZip) {
        Remove-Item -LiteralPath $OutputZip -Force
    }
    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $OutputZip -CompressionLevel Optimal

    Write-Host "Created LLVM LIT binary pack: $OutputZip"
    Write-Host ("Packaged files: {0}" -f $manifestFiles.Count)

    if ($RunLitSmoke) {
        Push-Location $binDir
        try {
            & python $llvmLit $clangTest --filter='^$' | Out-Host
            & python $llvmLit $lldTest --filter='^$' | Out-Host
        } finally {
            Pop-Location
        }
    }
} finally {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
