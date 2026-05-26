#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux runtime module requires a Linux host."
    exit 0
fi

cc="${CC:-cc}"
so="$out/liblinux_runtime_module.so"
"$cc" -O2 -Wall -Wextra -fPIC -shared -Wl,-soname,liblinux_runtime_module.so -o "$so" "$root/runtime_module.c"
echo "OK: $so"
