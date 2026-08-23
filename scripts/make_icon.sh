#!/bin/sh
# Regenerates the app icon from Shared/BrainView.swift.
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
cat Shared/BrainView.swift scripts/render_icon.swift > "$TMP/main.swift"
swiftc -O -swift-version 5 -o "$TMP/icon" "$TMP/main.swift" -framework SwiftUI -framework AppKit
"$TMP/icon" GrayMatter/Assets.xcassets/AppIcon.appiconset
