#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: macOS driver variants require a macOS host."
    exit 0
fi

cc="${CXX:-clang++}"

build_obj() {
    name="$1"
    src="$2"
    obj="$out/$name.o"
    echo "BUILD: $name"
    if "$cc" -std=c++17 -Wall -Wextra -c "$src" -o "$obj"; then
        :
    else
        echo "SKIP: $name is unsupported by this SDK/toolchain."
        rm -f "$obj"
    fi
}

build_obj macos_kext_victim "$root/kext/kext_victim.cpp"
build_obj macos_driverkit_victim "$root/driverkit/driverkit_victim.cpp"
cp "$root/kext/Info.plist" "$out/macos_kext_Info.plist"
cp "$root/driverkit/Info.plist" "$out/macos_driverkit_Info.plist"
