#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_app="$PWD/.build/WindowFixture.app"
mkdir -p "$fixture_app/Contents/MacOS"
swiftc -parse-as-library Tests/Fixtures/WindowFixture.swift -o "$fixture_app/Contents/MacOS/WindowFixture"
cat > "$fixture_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.everydock.windowfixture</string>
<key>CFBundleName</key><string>WindowFixture</string>
<key>CFBundleExecutable</key><string>WindowFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
echo "Built disposable window fixture: $fixture_app"
echo "Run with: open '$fixture_app'"
