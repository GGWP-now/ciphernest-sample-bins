# Windows Driver Variant Victims

Safe, compile-only skeletons for common Windows driver shapes:

- UMDF-style user-mode driver DLL entry surface
- KMDF-style kernel entry surface
- NDIS-flavored kernel entry surface
- WDM kernel entry surface
- simple no-framework kernel entry surface
- safeguarded no-framework variant with stricter build flags

The build script requires Visual Studio Build Tools plus the Windows Driver Kit.
It compiles objects only and does not install, sign, or load any driver.

```powershell
.\build.ps1 -Arch x64 -OutDir .\bin -SkipIfUnavailable
```
