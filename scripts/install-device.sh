#!/usr/bin/env bash
#
# Build, install and launch Shiori on the physical iPhone "TiPhone junior".
# On-demand dev helper — not part of the CI or release flow.
#
# Usage: scripts/install-device.sh
#
set -euo pipefail

DEVICE_ID="8F972B31-AA93-5250-B1BA-21912EF9733E" # TiPhone junior (iPhone 15 Pro)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "==> Building for device ${DEVICE_ID}"
# -allowProvisioningUpdates lets automatic signing register the device and mint
# the profile on first run; without it a fresh App ID fails with "no profile
# matching" and says nothing about why.
xcodebuild -project ios/Shiori.xcodeproj -scheme Shiori \
  -destination "platform=iOS,id=${DEVICE_ID}" \
  -derivedDataPath build/device \
  -allowProvisioningUpdates \
  build

APP="build/device/Build/Products/Debug-iphoneos/Shiori.app"

echo "==> Installing ${APP}"
xcrun devicectl device install app "$APP" --device "$DEVICE_ID"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

echo "==> Launching ${BUNDLE_ID}"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
