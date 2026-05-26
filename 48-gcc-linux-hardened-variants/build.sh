#!/bin/sh
set -eu

out="${1:-build}"
src="$(dirname "$0")/main.c"
mkdir -p "$out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: GCC Linux hardened variants require a Linux host."
    exit 0
fi

cc="${CC:-gcc}"
if ! command -v "$cc" >/dev/null 2>&1; then
    echo "SKIP: gcc not found."
    exit 0
fi

build_variant() {
    name="$1"
    cflags="$2"
    ldflags="$3"
    exe="$out/$name"
    echo "BUILD: $name"
    # shellcheck disable=SC2086
    if "$cc" $cflags -DVICTIM_VARIANT="\"$name\"" -Wall -Wextra -o "$exe" "$src" $ldflags; then
        "$exe" || true
    else
        echo "SKIP: $name flags are unsupported by this compiler/linker."
        rm -f "$exe"
    fi
}

build_variant gcc_linux_baseline "-O0 -g" ""
build_variant gcc_linux_relro_pie "-O2 -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=2" "-pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack"
build_variant gcc_linux_hardened_lto "-O2 -flto -fPIE -fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=2" "-flto -pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack"
