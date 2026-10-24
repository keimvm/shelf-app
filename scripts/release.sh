#!/bin/sh
# Builds Shelf (Release) and publishes it as the GitHub Release v<MARKETING_VERSION> with Shelf.zip attached.
# With --dry-run, only builds build/Shelf.zip.
set -eu
cd "$(dirname "$0")/.."

dry_run=false
case "${1:-}" in
    --dry-run) dry_run=true ;;
    "") ;;
    *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

commit=$(git rev-parse HEAD)
if ! $dry_run; then
    if [ -n "$(git status --porcelain)" ]; then
        echo "未コミットの変更があります。コミットしてから実行してください。" >&2
        exit 1
    fi
    git fetch --quiet origin
    if [ -z "$(git branch -r --contains "$commit")" ]; then
        echo "HEAD が GitHub に push されていません。git push してから実行してください。" >&2
        exit 1
    fi
fi

app=$(scripts/build.sh)
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
tag="v$version"
if ! $dry_run && gh release view "$tag" >/dev/null 2>&1; then
    echo "$tag は公開済みです。MARKETING_VERSION を上げてから実行してください。" >&2
    exit 1
fi

# ditto keeps the code signature intact; zip(1) can break it.
zip=build/Shelf.zip
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
if $dry_run; then
    echo "$zip を作りました（$tag、未公開）。"
    exit 0
fi

gh release create "$tag" "$zip" --target "$commit" --title "Shelf $version" --generate-notes
