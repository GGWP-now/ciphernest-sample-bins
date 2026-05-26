#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
app="$out/MacAmd64Victim.app"
exe="$app/Contents/MacOS/MacAmd64Victim"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "SKIP: macOS app AMD64 target requires macOS."
    exit 0
fi

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/Info.plist" "$app/Contents/Info.plist"

clang -arch x86_64 -O2 -Wall -Wextra -o "$exe" "$root/main.c"
chmod +x "$exe"
echo "OK: $app"
