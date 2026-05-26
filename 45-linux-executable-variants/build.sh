#!/bin/sh
set -eu

out="${1:-build}"
src="$(dirname "$0")/main.c"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux executable variants require a Linux host."
    exit 0
fi

build_with() {
    name="$1"
    shift
    exe="$out/$name"
    echo "BUILD: $name"
    if "$@" -O2 -Wall -Wextra -o "$exe" "$src"; then
        "$exe" "$name" || true
    else
        echo "SKIP: $name compiler/linker path is unavailable."
        rm -f "$exe"
    fi
}

build_with linux_x64 cc -m64
build_with linux_x86 cc -m32

if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
    build_with linux_armv7 arm-linux-gnueabihf-gcc
else
    echo "SKIP: arm-linux-gnueabihf-gcc not found."
fi

if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    build_with linux_aarch64 aarch64-linux-gnu-gcc
else
    echo "SKIP: aarch64-linux-gnu-gcc not found."
fi
