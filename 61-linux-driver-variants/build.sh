#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux driver variants require a Linux host."
    exit 0
fi

kbuild="/lib/modules/$(uname -r)/build"
if [ ! -d "$kbuild" ]; then
    echo "SKIP: Linux kernel headers/build directory not found at $kbuild."
    exit 0
fi

work="$out/kmod-src"
rm -rf "$work"
mkdir -p "$work"
cp "$root"/Makefile "$root"/*.c "$work"/

if [ -f "$kbuild/Module.symvers" ]; then
    make -C "$kbuild" M="$work" modules
else
    echo "WARN: $kbuild/Module.symvers is missing; building with KBUILD_MODPOST_WARN=1."
    make -C "$kbuild" M="$work" KBUILD_MODPOST_WARN=1 modules
fi
find "$work" -maxdepth 1 -name '*.ko' -exec cp {} "$out"/ \;
echo "OK: Linux driver variants built in $out"
