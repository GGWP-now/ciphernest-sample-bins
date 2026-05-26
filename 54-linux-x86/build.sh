#!/bin/sh
set -eu

out="${1:-build}"
root="$(dirname "$0")"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux x86 target requires a Linux host."
    exit 0
fi

exe="$out/linux_x86_victim"
if cc -m32 -O2 -Wall -Wextra -o "$exe" "$root/main.c"; then
    "$exe" || true
else
    echo "SKIP: cc -m32 failed; install 32-bit libc/multilib support."
    rm -f "$exe"
fi
