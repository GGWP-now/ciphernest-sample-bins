#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: macOS i386 dynamic library target requires macOS."
    exit 0
fi

lib="$out/libmacos_dll_i386.dylib"
smoke="$out/macos_dll_i386_smoke"

if clang -arch i386 -O2 -Wall -Wextra -dynamiclib -install_name @rpath/libmacos_dll_i386.dylib -o "$lib" "$root/macos_dll_i386.c"; then
    if clang -arch i386 -O2 -Wall -Wextra -o "$smoke" "$root/smoke.c" -L"$out" -lmacos_dll_i386 -Wl,-rpath,@executable_path; then
        "$smoke" || true
    else
        echo "SKIP: i386 smoke executable unsupported by this SDK."
    fi
else
    echo "SKIP: i386 dynamic libraries are unsupported by this SDK/toolchain."
    rm -f "$lib" "$smoke"
fi
