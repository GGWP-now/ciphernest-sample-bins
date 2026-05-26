#!/bin/sh
set -eu

out="${1:-build}"
src="$(dirname "$0")/main.c"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: macOS executable variants require a macOS host."
    exit 0
fi

cc="${CC:-clang}"

build_arch() {
    arch="$1"
    exe="$out/macos_exec_$arch"
    echo "BUILD: $arch"
    if "$cc" -arch "$arch" -O2 -Wall -Wextra -o "$exe" "$src"; then
        "$exe" "$arch" || true
    else
        echo "SKIP: architecture $arch is unsupported by this SDK/toolchain."
        rm -f "$exe"
    fi
}

build_arch i386
build_arch x86_64
build_arch arm64
