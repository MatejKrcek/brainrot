#!/bin/sh
# Archives the full app (Release) and uploads it to App Store Connect.
#   scripts/archive.sh            → archive + upload
#   scripts/archive.sh --no-upload → archive only (build/BrainHealth.xcarchive)
# Needs: Xcode signed in to the Apple ID of team HRZTF76M9G, and the Family Controls (Distribution)
# entitlement approved for com.matejkrcek.graymatter + the 4 Screen Time extensions (see AppStore/CHECKLIST.md).
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
ARCHIVE=build/BrainHealth.xcarchive
xcodegen generate >/dev/null
xcodebuild -project GrayMatter.xcodeproj -scheme GrayMatter -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates archive | tail -5
if [ "$1" = "--no-upload" ]; then echo "Archive at $ARCHIVE"; exit 0; fi
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates | tail -5
echo "Uploaded. Check App Store Connect → TestFlight in a few minutes."
