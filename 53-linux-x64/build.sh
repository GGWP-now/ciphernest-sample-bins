#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux x64 target requires a Linux host."
    exit 0
fi

exe="$out/linux_x64_victim"
if cc -m64 -O2 -Wall -Wextra -o "$exe" "$root/main.c"; then
    "$exe" || true
else
    echo "SKIP: cc -m64 failed on this host."
    rm -f "$exe"
fi
