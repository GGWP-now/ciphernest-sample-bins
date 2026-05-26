[CmdletBinding()]
param(
    [string]$WorkRoot = '',
    [string]$LLVMRef = 'llvmorg-20.1.0',
    [string]$OutputZip = '',
    [switch]$Fetch,
    [switch]$Configure,
    [switch]$Build,
    [switch]$BuildLitToolsOnly,
    [switch]$Package,
    [switch]$ForceConfigure,
    [switch]$RunLitSmoke
)

$ErrorActionPreference = 'Stop'

if ($WorkRoot -eq '') {
    $preferred = 'D:\llvm-lit-sigbreaker'
    $WorkRoot = if (Test-Path 'D:\') { $preferred } else { Join-Path $env:TEMP 'llvm-lit-sigbreaker' }
}

$WorkRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkRoot)
$llvmProjectDir = Join-Path $WorkRoot 'llvm-project'
$buildDir = Join-Path $llvmProjectDir 'build'

if ($OutputZip -eq '') {
    $OutputZip = Join-Path (Split-Path -Parent $PSCommandPath) 'original-llvm-lit-binaries.zip'
}
$OutputZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputZip)

function Invoke-Native {
    param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = '')
    $escapedArgs = foreach ($arg in $Arguments) {
        if ($arg -match '[\s;&|<>^"]') {
            '"' + ($arg -replace '"', '\"') + '"'
        } else {
            $arg
        }
    }
    $command = "$FilePath $($escapedArgs -join ' ')"
    if ($WorkingDirectory) {
        $command = "cd /d `"$WorkingDirectory`" && $command"
    }
    Write-Host "> $command" -ForegroundColor DarkGray
    cmd /s /c "$command 2>&1" | Tee-Object -Variable output | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath exited with $LASTEXITCODE"
    }
}

function Import-VSEnv {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsPath = ''
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -property installationPath 2>$null
    }
    if (-not $vsPath) {
        $candidates = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\18\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise"
        )
        $vsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $vsPath) {
        throw 'Visual Studio was not found. The SigBreaker README requires Visual Studio.'
    }
    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path $vcvars)) {
        throw "vcvarsall.bat not found: $vcvars"
    }
    Write-Host "Loading MSVC environment: $vcvars amd64" -ForegroundColor DarkGray
    $envBlock = cmd /s /c "`"$vcvars`" amd64 >NUL 2>&1 && set"
    foreach ($line in $envBlock) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
}

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

if ($Fetch) {
    if (Test-Path (Join-Path $llvmProjectDir '.git')) {
        Write-Host "LLVM checkout already exists: $llvmProjectDir"
        Push-Location $llvmProjectDir
        try {
            Invoke-Native git @('fetch', '--depth', '1', 'origin', "refs/tags/$LLVMRef`:refs/tags/$LLVMRef")
            Invoke-Native git @('checkout', '--force', $LLVMRef)
            Invoke-Native git @('submodule', 'update', '--init', '--recursive', '--depth', '1')
        } finally {
            Pop-Location
        }
    } else {
        Invoke-Native git @(
            'clone',
            '--recursive',
            '--depth', '1',
            '--branch', $LLVMRef,
            'https://github.com/llvm/llvm-project.git',
            $llvmProjectDir
        )
    }
}

if ($Configure) {
    if ((Test-Path $buildDir) -and $ForceConfigure) {
        Remove-Item -LiteralPath $buildDir -Recurse -Force
    }
    Import-VSEnv
    $configureArgs = @(
        '-S', (Join-Path $llvmProjectDir 'llvm'),
        '-B', $buildDir,
        '-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra;lld;lldb;polly;bolt;mlir;openmp',
        '-DLLVM_ENABLE_RUNTIMES=libcxx;libcxxabi;libunwind;compiler-rt',
        '-DCMAKE_BUILD_TYPE=Release'
    )
    Invoke-Native cmake $configureArgs
}

if ($Build) {
    Import-VSEnv
    if ($BuildLitToolsOnly) {
        $litTargets = @(
            'clang',
            'lld',
            'FileCheck',
            'count',
            'not',
            'split-file',
            'yaml2obj',
            'llvm-ar',
            'llvm-cxxfilt',
            'llvm-dis',
            'llvm-mc',
            'llvm-nm',
            'llvm-objcopy',
            'llvm-objdump',
            'llvm-profdata',
            'llvm-readobj',
            'llvm-size',
            'llvm-symbolizer',
            'opt'
        )
        foreach ($target in $litTargets) {
            Invoke-Native cmake @('--build', $buildDir, '--config', 'Release', '--target', $target)
        }
    } else {
        Invoke-Native cmake @('--build', $buildDir, '--config', 'Release')
    }
}

if ($Package) {
    $prepare = Join-Path (Split-Path -Parent $PSCommandPath) 'prepare_llvm_lit_binaries.ps1'
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $prepare,
        '-LLVMProjectDir', $llvmProjectDir,
        '-BuildDir', $buildDir,
        '-OutputZip', $OutputZip
    )
    if ($RunLitSmoke) {
        $args += '-RunLitSmoke'
    }
    Invoke-Native powershell $args
}

Write-Host "LLVM project: $llvmProjectDir"
Write-Host "LLVM build:   $buildDir"
Write-Host "Output ZIP:   $OutputZip"
