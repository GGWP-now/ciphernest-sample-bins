[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LLVMProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$BuildDir,

    [Parameter(Mandatory = $true)]
    [string]$OriginalZip,

    [Parameter(Mandatory = $true)]
    [string]$AlteredZip,

    [string]$ResultsDir = ''
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

$LLVMProjectDir = Resolve-RequiredPath $LLVMProjectDir 'LLVM project directory'
$BuildDir = Resolve-RequiredPath $BuildDir 'LLVM build directory'
$OriginalZip = Resolve-RequiredPath $OriginalZip 'original binary ZIP'
$AlteredZip = Resolve-RequiredPath $AlteredZip 'altered binary ZIP'

$binDir = Join-Path $BuildDir 'Release\bin'
if (-not (Test-Path (Join-Path $binDir 'llvm-lit.py'))) {
    $binDir = Join-Path $BuildDir 'bin'
}
$binDir = Resolve-RequiredPath $binDir 'LLVM binary directory'

$clangTest = Resolve-RequiredPath (Join-Path $LLVMProjectDir 'clang\test') 'clang lit test directory'
$lldTest = Resolve-RequiredPath (Join-Path $LLVMProjectDir 'lld\test') 'lld lit test directory'
$llvmLit = Resolve-RequiredPath (Join-Path $binDir 'llvm-lit.py') 'llvm-lit.py'

if ($ResultsDir -eq '') {
    $ResultsDir = Join-Path (Split-Path -Parent $PSCommandPath) 'lit-results'
}
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

function Invoke-LitSet {
    param([string]$ZipPath, [string]$Prefix)
    Expand-Archive -Path $ZipPath -DestinationPath $binDir -Force
    Push-Location $binDir
    try {
        & python $llvmLit $clangTest > (Join-Path $ResultsDir "$Prefix-clang-lit-results.txt")
        & python $llvmLit $lldTest > (Join-Path $ResultsDir "$Prefix-lld-lit-results.txt")
    } finally {
        Pop-Location
    }
}

Invoke-LitSet -ZipPath $OriginalZip -Prefix 'original'
Invoke-LitSet -ZipPath $AlteredZip -Prefix 'altered'

Write-Host "Wrote lit comparison results to $ResultsDir"
