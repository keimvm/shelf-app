#!/bin/sh
# Builds the finder-open spike into ./build. OpenSpike is ad-hoc signed with the App Sandbox.
set -eu
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"

app="$OUT/OpenSpike.app"
mkdir -p "$app/Contents/MacOS"
sed -e "s/__RANK__/${RANK:-None}/" -e "s/__ROLE__/${ROLE:-Viewer}/" OpenSpike/Info.plist > "$app/Contents/Info.plist"
swiftc -swift-version 5 -O OpenSpike/main.swift -o "$app/Contents/MacOS/OpenSpike"
codesign --force --sign - --entitlements "${ENTITLEMENTS:-OpenSpike/OpenSpike.entitlements}" "$app"
echo "built into $OUT"
