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
if [ ! -e "$kbuild/vmlinux" ] && [ -r /sys/kernel/btf/vmlinux ]; then
    ln -sf /sys/kernel/btf/vmlinux "$kbuild/vmlinux" 2>/dev/null || true
fi

work="$out/kmod-src"
rm -rf "$work"
mkdir -p "$work"
cp "$root"/Makefile "$root"/*.c "$work"/

run_kbuild() {
    log="$work/kbuild.log"
    if make -C "$kbuild" M="$work" "$@" modules >"$log" 2>&1; then
        sed \
            -e '/You may get many unresolved symbol errors\./d' \
            -e '/You can set KBUILD_MODPOST_WARN=1 to turn errors into warning/d' \
            -e '/Skipping BTF generation for .* due to unavailability of vmlinux/d' \
            "$log"
    else
        cat "$log"
        return 1
    fi
}

if [ -f "$kbuild/Module.symvers" ]; then
    run_kbuild
else
    echo "WARN: $kbuild/Module.symvers is missing; building with KBUILD_MODPOST_WARN=1."
    run_kbuild KBUILD_MODPOST_WARN=1
fi
find "$work" -maxdepth 1 -name '*.ko' -exec cp {} "$out"/ \;
echo "OK: Linux driver variants built in $out"
