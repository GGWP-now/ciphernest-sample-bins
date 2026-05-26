# Delphi MAP Victim

Builds a small Win32 Delphi-style console program and asks the compiler/linker
for a detailed MAP file. The script uses `dcc32` when available and falls back
to Free Pascal (`fpc`) in Delphi compatibility mode.

```powershell
.\build.ps1 -OutDir .\bin -SkipIfUnavailable
```
