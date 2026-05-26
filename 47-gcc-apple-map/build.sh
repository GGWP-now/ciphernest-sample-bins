#!/bin/sh
set -eu

out="${1:-build}"
src="$(dirname "$0")/main.c"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: Apple map builds require a macOS host."
    exit 0
fi

cc="${CC:-gcc}"
if ! command -v "$cc" >/dev/null 2>&1; then
    cc=clang
fi

build_arch() {
    arch="$1"
    exe="$out/gcc_apple_map_$arch"
    map="$out/gcc_apple_map_$arch.map"
    echo "BUILD: $arch"
    if "$cc" -arch "$arch" -O2 -g -Wall -Wextra -Wl,-map,"$map" -o "$exe" "$src"; then
        "$exe" "$arch" || true
    else
        echo "SKIP: Apple map build failed for $arch."
        rm -f "$exe" "$map"
    fi
}

build_arch x86_64
build_arch arm64
