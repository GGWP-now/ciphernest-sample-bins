# MSVC MAP Hardened Variants

Builds three MSVC console executables and emits `.map` files for each:

- `msvc_debug_map`
- `msvc_release_cf_map`
- `msvc_ltcg_hardened_map`

Run from a Visual Studio developer shell or through `build_matrix.ps1`.

```powershell
.\build.ps1 -Arch x64 -OutDir .\bin -SkipIfUnavailable
```
