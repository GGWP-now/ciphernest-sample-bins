# UEFI Driver Victim

Minimal EDK II DXE driver module. The build script detects an initialized EDK II
workspace and runs `build` when available; otherwise it skips cleanly.

```powershell
.\build.ps1 -OutDir .\bin -SkipIfUnavailable
```
