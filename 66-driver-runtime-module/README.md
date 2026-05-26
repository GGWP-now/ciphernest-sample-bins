# Driver Runtime Module Victim

Compile-only Windows driver support module intended to model a runtime object
linked into a driver. The script requires the Windows Driver Kit and emits an
object/static library when available; it does not produce or load a driver.

```powershell
.\build.ps1 -Arch x64 -OutDir .\bin -SkipIfUnavailable
```
