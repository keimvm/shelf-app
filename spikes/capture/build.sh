#!/bin/sh
# Builds the capture spike into ./build. CaptureSpike is ad-hoc signed with the App Sandbox.
# KEY sets the service's default key equivalent (key-binding notation, e.g. ^~@p).
set -eu
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"

app="$OUT/CaptureSpike.app"
mkdir -p "$app/Contents/MacOS"
sed -e "s/__KEY__/${KEY:-}/" CaptureSpike/Info.plist > "$app/Contents/Info.plist"
swiftc -swift-version 5 -O CaptureSpike/main.swift -o "$app/Contents/MacOS/CaptureSpike"
codesign --force --sign - --entitlements CaptureSpike/CaptureSpike.entitlements "$app"
swiftc -swift-version 5 -O Driver/main.swift -o "$OUT/driver"
echo "built into $OUT"
