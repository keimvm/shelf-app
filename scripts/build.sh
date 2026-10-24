#!/bin/sh
# Builds Shelf (Release) into build/DerivedData.noindex and prints the path of Shelf.app.
set -eu
cd "$(dirname "$0")/.."

xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData.noindex -quiet build >&2
echo "$PWD/build/DerivedData.noindex/Build/Products/Release/Shelf.app"
