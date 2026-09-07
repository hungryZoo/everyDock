#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo "Usage: ./scripts/build.sh [release|debug]" >&2
    exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
    echo "everyDock requires an Apple Silicon Mac." >&2
    exit 1
fi

export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
swift build -c "$configuration" --arch arm64 --scratch-path .build
bin_path="$(swift build -c "$configuration" --arch arm64 --scratch-path .build --show-bin-path)"
output_dir="${EVERYDOCK_OUTPUT_DIR:-$PWD/dist}"
app="$output_dir/everyDock.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/everyDock" "$app/Contents/MacOS/everyDock"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$app"
codesign --verify --deep --strict "$app"
echo "Built: $app"
