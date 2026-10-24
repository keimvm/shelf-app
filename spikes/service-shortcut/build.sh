#!/bin/sh
# Builds the service shortcut spike into ./build. PrefsSpike is ad-hoc signed with the App Sandbox.
set -eu
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"

app="$OUT/PrefsSpike.app"
mkdir -p "$app/Contents/MacOS"
cp PrefsSpike/Info.plist "$app/Contents/Info.plist"
swiftc -swift-version 5 -O PrefsSpike/main.swift -o "$app/Contents/MacOS/PrefsSpike"
codesign --force --sign - --entitlements PrefsSpike/PrefsSpike.entitlements "$app"
echo "built into $OUT"
