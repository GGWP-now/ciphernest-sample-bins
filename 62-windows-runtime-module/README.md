# Windows Runtime Module Victim

Builds a small native Windows DLL with a `DllMain` and one exported runtime
probe function.

```powershell
.\build.ps1 -Arch x64 -OutDir .\bin -SkipIfUnavailable
```
