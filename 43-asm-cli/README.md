# ASM CLI Victim

Tiny Windows console executable generated directly from bytes.

The goal is the same spirit as DEBUG-script minimalism: keep the executable
small and self-contained, with no CRT, assembler, or linker in the build path.
Unlike a DOS `.COM` sample, this emits a real Windows PE console `.exe`.

`build.ps1` writes a PE32 x86 executable containing:

- a minimal DOS/PE header
- one writable/executable `.text` section
- 37 bytes of x86 code
- a short message string
- a minimal import table for `KERNEL32.dll`

The program calls only:

- `GetStdHandle`
- `WriteFile`
- `ExitProcess`

Build:

```powershell
.\build.ps1
```

Matrix build:

```powershell
..\build_matrix.ps1 -Targets 43 -Configs x64_Release
```

Output: `tiny_asm_cli.exe`.
