#!/bin/sh
# Builds Shelf (Release), replaces /Applications/Shelf.app with it, and launches it.
set -eu
cd "$(dirname "$0")/.."
dest=/Applications/Shelf.app

if pgrep -xq Shelf; then
    echo "Shelf が起動しています。メニューの「Shelf を終了」で終了してから実行してください。" >&2
    exit 1
fi
# Refuse to delete an unrelated app that happens to be named Shelf.app.
if [ -e "$dest" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$dest/Contents/Info.plist" 2>/dev/null)" != dev.keimvm.Shelf ]; then
    echo "$dest は別のアプリです。置き換えません。" >&2
    exit 1
fi

app=$(scripts/build.sh)
# Remove first: ditto merges into an existing bundle and would keep stale files.
rm -rf "$dest"
ditto "$app" "$dest"
open "$dest"
echo "$dest を更新しました。"
