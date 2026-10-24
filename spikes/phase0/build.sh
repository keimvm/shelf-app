#!/bin/sh
# Builds the Phase 0 spike apps into ./build. ShelfSpike is ad-hoc signed with the App Sandbox.
set -eu
cd "$(dirname "$0")"
OUT=build
rm -rf "$OUT"

bundle() { # name, entitlements(optional)
    app="$OUT/$1.app"
    mkdir -p "$app/Contents/MacOS"
    cp "$1/Info.plist" "$app/Contents/Info.plist"
    swiftc -swift-version 5 -O "$1/main.swift" -o "$app/Contents/MacOS/$1"
    if [ -n "${2:-}" ]; then
        codesign --force --sign - --entitlements "$2" "$app"
    else
        codesign --force --sign - "$app"
    fi
}

bundle ShelfSpike ShelfSpike/ShelfSpike.entitlements
bundle DragSource
swiftc -swift-version 5 -O Driver/main.swift -o "$OUT/driver"
echo "built into $OUT"
