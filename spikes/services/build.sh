#!/bin/sh
# Builds the services spike into ./build. ServiceSpike is ad-hoc signed with the App Sandbox.
# KEY_FILES / KEY_EMPTY set the services' default key equivalents (key-binding notation, e.g. ^~@n).
set -eu
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"

app="$OUT/ServiceSpike.app"
mkdir -p "$app/Contents/MacOS"
sed -e "s/__KEY_FILES__/${KEY_FILES:-}/" -e "s/__KEY_EMPTY__/${KEY_EMPTY:-}/" ServiceSpike/Info.plist > "$app/Contents/Info.plist"
swiftc -swift-version 5 -O ServiceSpike/main.swift -o "$app/Contents/MacOS/ServiceSpike"
codesign --force --sign - --entitlements ServiceSpike/ServiceSpike.entitlements "$app"
swiftc -swift-version 5 -O Driver/main.swift -o "$OUT/driver"
echo "built into $OUT"
