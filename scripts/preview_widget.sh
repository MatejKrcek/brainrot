#!/bin/sh
# Renders the Home Screen sizes of the Screen time widget to a PNG on macOS. usage: scripts/preview_widget.sh out.png [dark|store]
set -e
cd "$(dirname "$0")/.."
OUT=${1:-widget_preview.png}
TMP=$(mktemp -d)
# HealthWidgetContent only (strip the WidgetKit-bound HealthWidgetView/HealthWidget definitions and the #Preview).
awk '/^\/\/\/ Layout per family/{p=1} /^struct HealthWidget: Widget/{p=0} p' GrayMatterWidget/HealthWidget.swift > "$TMP/content.swift"
cat Shared/BrainView.swift Shared/RotModel.swift Shared/Alternatives.swift "$TMP/content.swift" scripts/preview_widget.swift > "$TMP/main.swift"
swiftc -O -swift-version 5 -o "$TMP/preview" "$TMP/main.swift" -framework SwiftUI -framework AppKit -framework WidgetKit
"$TMP/preview" "$OUT" ${2:-}
