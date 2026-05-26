#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: macOS runtime module requires a macOS host."
    exit 0
fi

cc="${CC:-clang}"
dylib="$out/libmacos_runtime_module.dylib"
"$cc" -O2 -Wall -Wextra -fPIC -dynamiclib -install_name @rpath/libmacos_runtime_module.dylib -o "$dylib" "$root/runtime_module.c"
echo "OK: $dylib"
