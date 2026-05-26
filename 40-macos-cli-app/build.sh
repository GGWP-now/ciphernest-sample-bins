#!/bin/sh
set -eu

out="${1:-build}"
mkdir -p "$out"
swiftc -O -o "$out/macos_cli_app" Sources/main.swift
"$out/macos_cli_app" matrix-safe
