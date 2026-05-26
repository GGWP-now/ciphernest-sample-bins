# IL and .NET Runtime Module Victims

Builds or stages runtime module variants for:

- raw IL (`ilasm`) when available
- .NET Framework 2.0 (`csc.exe` v2) when available
- .NET Framework 4.x (`csc.exe` v4) when available
- .NET Core (`netcoreapp3.1`) when the SDK targeting pack is installed
- .NET Standard (`netstandard2.0`) when the SDK targeting pack is installed

Unavailable legacy targeting packs are skipped without failing the matrix.

```powershell
.\build.ps1 -OutDir .\bin -SkipIfUnavailable
```
