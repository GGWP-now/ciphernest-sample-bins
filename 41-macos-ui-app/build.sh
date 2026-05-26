#!/bin/sh
set -eu

out="${1:-build}"
app="$out/MacVictimUI.app"
contents="$app/Contents"
macos="$contents/MacOS"
resources="$contents/Resources"

rm -rf "$app"
mkdir -p "$macos" "$resources"
swiftc -O -o "$macos/MacVictimUI" Sources/MacVictimUI.swift
cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MacVictimUI</string>
  <key>CFBundleIdentifier</key>
  <string>local.protector.macvictimui</string>
  <key>CFBundleName</key>
  <string>Mac Victim UI</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
</dict>
</plist>
PLIST
echo "Built $app"
