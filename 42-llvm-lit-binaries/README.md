# LLVM LIT Binary Pack

This target prepares LLVM binary archives for clang/lld lit stability testing.

Expected upstream layout:

```powershell
git clone --recursive -b llvmorg-20.1.0 https://github.com/llvm/llvm-project.git
cd llvm-project
cmake -S llvm -B build `
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb;polly;bolt;mlir;openmp" `
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt" `
  -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

Package the binaries:

```powershell
.\prepare_llvm_lit_binaries.ps1 `
  -LLVMProjectDir G:\path\to\llvm-project `
  -BuildDir G:\path\to\llvm-project\build `
  -OutputZip G:\path\to\original-llvm-lit-binaries.zip
```

The archive is intended to be expanded into `llvm-project\build\Release\bin`:

```powershell
Expand-Archive -Path .\original-llvm-lit-binaries.zip -DestinationPath .\build\Release\bin -Force
cd .\build\Release\bin
python llvm-lit.py ..\..\..\clang\test > original-clang-lit-results.txt
python llvm-lit.py ..\..\..\lld\test > original-lld-lit-results.txt
```

Use `run_lit_comparison.ps1` to automate baseline and altered runs when you
have an original ZIP and a transformed ZIP.

End-to-end fetch/configure/build/package helper:

```powershell
.\fetch_build_llvm_lit_binaries.ps1 `
  -WorkRoot D:\llvm-lit `
  -Fetch -Configure -Build -Package
```

On Windows/MSVC, LLVM 20.1.0's `libunwind` runtime intentionally refuses to
configure for MSVC ABI targets. For a SigBreaker-compatible clang/lld lit binary
pack on Windows, use:

```powershell
.\fetch_build_llvm_lit_binaries.ps1 `
  -WorkRoot D:\llvm-lit-sigbreaker `
  -Fetch -Configure -Build -BuildLitToolsOnly -Package
```

The helper intentionally lives outside the normal matrix fast path. Building
LLVM with clang, lld, lldb, polly, bolt, mlir, openmp, and runtimes is large,
so `build_matrix.ps1 -Targets 42` packages only when `LLVM_PROJECT_DIR` and
`LLVM_BUILD_DIR` point at an existing build.
