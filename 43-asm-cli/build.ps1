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

if ($OutDir -eq '') {
    $OutDir = Join-Path $Root 'bin'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$outFile = Join-Path $OutDir 'tiny_asm_cli.exe'
if ($Clean) {
    foreach ($name in @('tiny_asm_cli.exe', 'asm_cli.exe', 'myhello.com')) {
        $path = Join-Path $OutDir $name
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

# Keep this intentionally tiny and explicit:
# - PE32 x86 console executable, because PE32 is smaller and runs on x64 Windows
#   through WoW64.
# - No CRT, assembler, or linker.
# - One .text section that contains code, data, import descriptors, INT, IAT,
#   and import-by-name records.
# - Calls only kernel32!GetStdHandle, kernel32!WriteFile, and
#   kernel32!ExitProcess.

$ImageBase = 0x00400000
$SectionRva = 0x1000
$SectionRaw = 0x200
$FileAlignment = 0x200
$SectionAlignment = 0x1000
$FileSize = 0x400
$SectionSize = 0x200

$Message = "tiny asm cli`r`n"
$MessageBytes = [System.Text.Encoding]::ASCII.GetBytes($Message)
$MessageRva = 0x1040
$BytesWrittenRva = 0x1050
$ImportRva = 0x1060
$DllNameRva = 0x10A0
$ImportLookupRva = 0x10B0
$ImportAddressRva = 0x10C0
$GetStdHandleNameRva = 0x10D0
$WriteFileNameRva = 0x10E0
$ExitProcessNameRva = 0x10EC

[byte[]]$script:File = New-Object byte[] $FileSize

function Set-U16 {
    param([int]$Offset, [int]$Value)
    $script:File[$Offset] = [byte]($Value -band 0xFF)
    $script:File[$Offset + 1] = [byte](($Value -shr 8) -band 0xFF)
}

function Set-U32 {
    param([int]$Offset, [long]$Value)
    $signed = [int64]$Value
    if ($signed -lt 0) {
        $signed += 0x100000000
    }
    $v = [uint64]$signed
    $script:File[$Offset] = [byte]($v -band 0xFF)
    $script:File[$Offset + 1] = [byte](($v -shr 8) -band 0xFF)
    $script:File[$Offset + 2] = [byte](($v -shr 16) -band 0xFF)
    $script:File[$Offset + 3] = [byte](($v -shr 24) -band 0xFF)
}

function Rva-To-Offset {
    param([int]$Rva)
    return $SectionRaw + ($Rva - $SectionRva)
}

function Va {
    param([int]$Rva)
    return [uint32]($ImageBase + $Rva)
}

function Write-Ascii {
    param([int]$Offset, [string]$Text, [switch]$NullTerminated)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Text)
    [Array]::Copy($bytes, 0, $script:File, $Offset, $bytes.Length)
    if ($NullTerminated) {
        $script:File[$Offset + $bytes.Length] = 0
    }
}

function Write-Bytes {
    param([int]$Offset, [byte[]]$Bytes)
    [Array]::Copy($Bytes, 0, $script:File, $Offset, $Bytes.Length)
}

function New-U32Bytes {
    param([long]$Value)
    $signed = [int64]$Value
    if ($signed -lt 0) {
        $signed += 0x100000000
    }
    $v = [uint64]$signed
    return [byte[]]@(
        [byte]($v -band 0xFF),
        [byte](($v -shr 8) -band 0xFF),
        [byte](($v -shr 16) -band 0xFF),
        [byte](($v -shr 24) -band 0xFF)
    )
}

# DOS header: only the MZ signature and e_lfanew are needed by the PE loader.
Write-Ascii 0x00 'MZ'
Set-U32 0x3C 0x80

# NT headers.
$nt = 0x80
Write-Ascii $nt "PE`0`0"

# COFF header.
$coff = $nt + 4
Set-U16 ($coff + 0) 0x014C   # IMAGE_FILE_MACHINE_I386
Set-U16 ($coff + 2) 1        # one section
Set-U32 ($coff + 4) 0
Set-U32 ($coff + 8) 0
Set-U32 ($coff + 12) 0
Set-U16 ($coff + 16) 0x00E0  # PE32 optional header size
Set-U16 ($coff + 18) 0x010F  # executable, 32-bit, stripped

# Optional header (PE32).
$opt = $coff + 20
Set-U16 ($opt + 0) 0x010B
Set-U32 ($opt + 4) $SectionSize
Set-U32 ($opt + 8) 0
Set-U32 ($opt + 12) 0
Set-U32 ($opt + 16) $SectionRva
Set-U32 ($opt + 20) $SectionRva
Set-U32 ($opt + 24) $SectionRva
Set-U32 ($opt + 28) $ImageBase
Set-U32 ($opt + 32) $SectionAlignment
Set-U32 ($opt + 36) $FileAlignment
Set-U16 ($opt + 40) 4
Set-U16 ($opt + 48) 4
Set-U32 ($opt + 56) 0x2000
Set-U32 ($opt + 60) $SectionRaw
Set-U16 ($opt + 68) 3        # console subsystem
Set-U16 ($opt + 70) 0
Set-U32 ($opt + 72) 0x100000
Set-U32 ($opt + 76) 0x1000
Set-U32 ($opt + 80) 0x100000
Set-U32 ($opt + 84) 0x1000
Set-U32 ($opt + 92) 16
Set-U32 ($opt + 104) $ImportRva
Set-U32 ($opt + 108) 0x9A

# Section header.
$section = $opt + 0xE0
Write-Ascii $section '.text'
Set-U32 ($section + 8) $SectionSize
Set-U32 ($section + 12) $SectionRva
Set-U32 ($section + 16) $SectionSize
Set-U32 ($section + 20) $SectionRaw
Set-U32 ($section + 36) 0xE0000020 # code | execute | read | write

# x86 code:
#   push -11
#   call [GetStdHandle]
#   push 0
#   push &bytes_written
#   push len
#   push &message
#   push eax
#   call [WriteFile]
#   push 0
#   call [ExitProcess]
$code = New-Object System.Collections.Generic.List[byte]
foreach ($b in [byte[]]@(0x6A, 0xF5, 0xFF, 0x15)) { [void]$code.Add($b) }
foreach ($b in (New-U32Bytes (Va $ImportAddressRva))) { [void]$code.Add($b) }
foreach ($b in [byte[]]@(0x6A, 0x00, 0x68)) { [void]$code.Add($b) }
foreach ($b in (New-U32Bytes (Va $BytesWrittenRva))) { [void]$code.Add($b) }
foreach ($b in [byte[]]@(0x6A, [byte]$MessageBytes.Length, 0x68)) { [void]$code.Add($b) }
foreach ($b in (New-U32Bytes (Va $MessageRva))) { [void]$code.Add($b) }
foreach ($b in [byte[]]@(0x50, 0xFF, 0x15)) { [void]$code.Add($b) }
foreach ($b in (New-U32Bytes (Va ($ImportAddressRva + 4)))) { [void]$code.Add($b) }
foreach ($b in [byte[]]@(0x6A, 0x00, 0xFF, 0x15)) { [void]$code.Add($b) }
foreach ($b in (New-U32Bytes (Va ($ImportAddressRva + 8)))) { [void]$code.Add($b) }
Write-Bytes (Rva-To-Offset $SectionRva) $code.ToArray()

Write-Bytes (Rva-To-Offset $MessageRva) $MessageBytes
Set-U32 (Rva-To-Offset $BytesWrittenRva) 0

# Import descriptor for KERNEL32.dll.
$import = Rva-To-Offset $ImportRva
Set-U32 ($import + 0) $ImportLookupRva
Set-U32 ($import + 12) $DllNameRva
Set-U32 ($import + 16) $ImportAddressRva
Write-Ascii (Rva-To-Offset $DllNameRva) 'KERNEL32.dll' -NullTerminated

# Import lookup table and import address table.
$lookup = Rva-To-Offset $ImportLookupRva
$iat = Rva-To-Offset $ImportAddressRva
$imports = @($GetStdHandleNameRva, $WriteFileNameRva, $ExitProcessNameRva, 0)
for ($i = 0; $i -lt $imports.Count; $i++) {
    Set-U32 ($lookup + ($i * 4)) $imports[$i]
    Set-U32 ($iat + ($i * 4)) $imports[$i]
}

# Import-by-name records.
Set-U16 (Rva-To-Offset $GetStdHandleNameRva) 0
Write-Ascii ((Rva-To-Offset $GetStdHandleNameRva) + 2) 'GetStdHandle' -NullTerminated
Set-U16 (Rva-To-Offset $WriteFileNameRva) 0
Write-Ascii ((Rva-To-Offset $WriteFileNameRva) + 2) 'WriteFile' -NullTerminated
Set-U16 (Rva-To-Offset $ExitProcessNameRva) 0
Write-Ascii ((Rva-To-Offset $ExitProcessNameRva) + 2) 'ExitProcess' -NullTerminated

[System.IO.File]::WriteAllBytes($outFile, $script:File)

Write-Host "Tiny raw PE build"
Write-Host "  Arch request : $Arch (emits PE32 x86 for minimum size)"
Write-Host "  Config       : $Configuration"
Write-Host "  Output       : $outFile"
Write-Host "  Size         : $($script:File.Length) bytes"
Write-Host "  Code bytes   : $($code.Count)"
Write-Host "OK: $outFile"
