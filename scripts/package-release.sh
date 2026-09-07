#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

release_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected a semantic release version in Resources/Info.plist" >&2
    exit 1
fi

mkdir -p .build dist/releases
release_stage="$(mktemp -d "$PWD/.build/release-stage.XXXXXX")"
trap 'rm -rf "$release_stage"' EXIT

# Keep a running development app in dist/everyDock.app untouched.
EVERYDOCK_OUTPUT_DIR="$release_stage" ./scripts/build.sh release
release_app="$release_stage/everyDock.app"
release_binary="$release_app/Contents/MacOS/everyDock"
[[ "$(lipo -archs "$release_binary")" == "arm64" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$release_app/Contents/Info.plist")" == "26.0" ]]

# Exclude local debug symbols and Finder extended metadata from the public asset.
strip -S "$release_binary"
codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$release_app"
codesign --verify --deep --strict "$release_app"

release_asset="everyDock-$release_version-arm64.zip"
ditto -c -k --keepParent --noextattr --norsrc "$release_app" "$PWD/dist/releases/$release_asset"
(
    cd dist/releases
    shasum -a 256 "$release_asset" > SHA256SUMS
)
echo "Packaged: dist/releases/$release_asset"
cat dist/releases/SHA256SUMS
