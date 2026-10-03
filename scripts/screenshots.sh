#!/usr/bin/env bash
#
# Captures the App Store screens, from the showcase library the Debug build
# carries (ios/Shiori/Shared/Showcase.swift). No server, no account: the app is
# launched with -showcase and every read answers from that library.
#
#   scripts/screenshots.sh        # into screenshots/captures/fr/
#
# Runs on the Mac, never in CI: the captures change when a screen does, not on
# every release. Then: bun scripts/generate-appstore-previews.ts.
set -euo pipefail

cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# The 6.9" iPhone the App Store asks for, 1320x2868: a capture is never rescaled.
# A simulator of its own, so a run never photographs another session's state.
DEVICE_NAME="Shiori Captures"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
BUNDLE_ID="com.polyforms.shiori.app"
DESTINATION_DIR="screenshots/captures/fr"
EXPECTED=9

udid=$(xcrun simctl list devices available -j | bun -e '
  const { devices } = JSON.parse(await Bun.stdin.text())
  const found = Object.values(devices).flat().find((d) => d.name === process.argv[1])
  console.log(found?.udid ?? "")
' "$DEVICE_NAME")
if [ -z "$udid" ]; then
  runtime=$(xcrun simctl list runtimes available -j | bun -e '
    const { runtimes } = JSON.parse(await Bun.stdin.text())
    console.log(runtimes.filter((r) => r.platform === "iOS").at(-1)?.identifier ?? "")
  ')
  udid=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$runtime")
fi
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null

# Apple's own marketing status bar: 9:41, full signal, full battery.
xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi

# A fresh install every run, before the photos permission is granted to it: the app keeps the covers it fetched on disk, keyed by
# address, and a cover replaced under the same file name would otherwise show stale.
xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true

# The scan starts from the add sheet's last photo: the cover, and the right to read it.
# On a simulator whose Photos never opened, addmedia waits forever for a library
# that does not exist yet: opening Photos once creates it.
xcrun simctl privacy "$udid" grant photos "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" com.apple.mobileslideshow >/dev/null
sleep 3
xcrun simctl addmedia "$udid" screenshots/covers/hyperion.jpg &
addmedia=$!
for _ in $(seq 1 30); do kill -0 "$addmedia" 2>/dev/null || break; sleep 2; done
if kill -0 "$addmedia" 2>/dev/null; then
  kill "$addmedia"
  echo "error: simctl addmedia did not return within a minute." >&2
  exit 1
fi
wait "$addmedia"
xcrun simctl terminate "$udid" com.apple.mobileslideshow 2>/dev/null || true

rm -rf "$DESTINATION_DIR"
mkdir -p "$DESTINATION_DIR"

echo "==> Capturing on $DEVICE_NAME ($udid)"
xcodebuild test \
  -project ios/Shiori.xcodeproj \
  -scheme Shiori \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath build/screenshots \
  -only-testing:ShioriUITests/ScreenshotTest \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  | grep -E "error:|Test Case|\*\* TEST" || true

# The test writes the files itself: a green run that wrote nothing is a failure.
count=$(find "$DESTINATION_DIR" -name '*.png' | wc -l | tr -d ' ')
if [ "$count" -lt "$EXPECTED" ]; then
  echo "error: $DESTINATION_DIR holds $count captures, $EXPECTED expected." >&2
  exit 1
fi
ls -1 "$DESTINATION_DIR"
