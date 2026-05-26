#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
src="$root/main.m"
plist="$root/Info.plist"
mkdir -p "$out"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: iOS app variants require macOS with Xcode."
    exit 0
fi

if ! command -v xcrun >/dev/null 2>&1; then
    echo "SKIP: xcrun not found."
    exit 0
fi

build_app() {
    name="$1"
    sdk="$2"
    arch="$3"
    minflag="$4"
    sdkpath="$(xcrun --sdk "$sdk" --show-sdk-path 2>/dev/null || true)"
    cc="$(xcrun --sdk "$sdk" --find clang 2>/dev/null || true)"
    if [ -z "$sdkpath" ] || [ -z "$cc" ]; then
        echo "SKIP: SDK $sdk not available for $name."
        return 0
    fi

    app="$out/$name.app"
    mkdir -p "$app"
    cp "$plist" "$app/Info.plist"
    echo "BUILD: $name [$arch]"
    if "$cc" -arch "$arch" -isysroot "$sdkpath" "$minflag" -fobjc-arc -framework UIKit -o "$app/IosVictim" "$src"; then
        :
    else
        echo "SKIP: $name is unsupported by this Xcode SDK."
        rm -rf "$app"
    fi
}

build_app ios_i386_sim iphonesimulator i386 -mios-simulator-version-min=8.0
build_app ios_armv7 iphoneos armv7 -miphoneos-version-min=8.0
build_app ios_arm64 iphoneos arm64 -miphoneos-version-min=11.0
