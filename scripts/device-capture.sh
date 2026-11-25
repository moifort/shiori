#!/usr/bin/env bash
#
# Captures one showcase screen on the physical iPhone "TiPhone junior", in
# place of the simulator: builds if needed, installs if the build changed,
# opens the screen from the showcase fixtures (no server, no account), writes
# the PNG, and closes the app again.
#
#   scripts/device-capture.sh <screen> [light|dark] <out.png> [-- <app arguments>…]
#
#   <screen>   home | library | news | friends — the tab the app opens on;
#              or a page drawn alone from its fixtures, named as Android's
#              preview extras: goodreads | goodreads-explain | goodreads-reading
#              | goodreads-books | goodreads-done | goodreads-source
#              | subscription-trial | subscription-lapsed | premium
#              | libraries | libraries-all (the onboarding's libraries step)
#              | goodreads-same-book | goodreads-progress | goodreads-not-goodreads
#              | goodreads-empty | player-sleep
#   -- -showcase-anchor center|bottom  opens a long page scrolled, for a stitched capture
#   [light|dark]  the appearance, whatever the phone is set to (default: the phone's)
#   -- …       more launch arguments for the app, e.g. -- -showcase-prompts audible
#
# The iPhone is the reader's own, signed in to a real account. The showcase
# never reaches the server (ShowcaseNetworkGuard), leaves the share
# extension's item alone and puts the app's defaults back on the next ordinary
# launch (ShowcaseDevice), so the account and its data are left untouched.
# Never uninstall the app to "start clean": that wipes the reader's sign-in.
#
# One session at a time: the lock is build/ios-device.lock in the main
# checkout, shared by every worktree. A dead owner's lock is taken over.
#
# Environment:
#   SHIORI_DEVICE   device name or id (default: TiPhone junior)
#   SETTLE          seconds between launch and capture (default: 5)
#   SKIP_BUILD=1    capture the build already installed
set -euo pipefail

usage() {
  sed -n '8,20p' "$0" >&2
  exit 2
}

SCREEN="${1:-}"
[ -n "$SCREEN" ] || usage
shift
APPEARANCE=""
case "${1:-}" in
  light | dark) APPEARANCE="$1"; shift ;;
esac
OUT="${1:-}"
[ -n "$OUT" ] || usage
shift
[ "${1:-}" = "--" ] && shift
EXTRA_ARGS=("$@")

case "$SCREEN" in
  home | library | news | friends) SCREEN_FLAG=-showcase-tab ;;
  goodreads | goodreads-explain | goodreads-reading | goodreads-books | goodreads-done | goodreads-source \
    | subscription-trial | subscription-lapsed | premium | libraries | libraries-all \
    | goodreads-same-book | goodreads-progress | goodreads-not-goodreads | goodreads-empty | player-sleep)
    SCREEN_FLAG=-showcase-screen ;;
  *) echo "error: unknown screen '$SCREEN' (home, library, news, friends, goodreads…)" >&2; exit 2 ;;
esac
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac

cd "$(dirname "$0")/.."
WORKTREE="$PWD"
MAIN_CHECKOUT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEVICE="${SHIORI_DEVICE:-TiPhone junior}"
BUNDLE_ID="com.polyforms.shiori.app"
SETTLE="${SETTLE:-5}"
# Xcode's own DerivedData for the main checkout, as every other build of it
# uses; a fixed folder per worktree otherwise. Never a fresh path, never /tmp.
MAIN_DERIVED_DATA=""
for info in "$HOME"/Library/Developer/Xcode/DerivedData/Shiori-*/info.plist; do
  if [ "$(plutil -extract WorkspacePath raw "$info" 2>/dev/null)" = "$MAIN_CHECKOUT/ios/Shiori.xcodeproj" ]; then
    MAIN_DERIVED_DATA="$(dirname "$info")"
  fi
done
if [ "$WORKTREE" = "$MAIN_CHECKOUT" ] && [ -n "$MAIN_DERIVED_DATA" ]; then
  DERIVED_DATA="$MAIN_DERIVED_DATA"
else
  DERIVED_DATA="$WORKTREE/build/dd"
fi
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/Shiori.app"
COVERS_ON_DEVICE="Library/Caches/showcase-covers"

step() {
  printf '==> %s\n' "$1" >&2
}

elapsed() {
  printf '    %ss\n' "$(($(date +%s) - $1))" >&2
}

# --- The lock -----------------------------------------------------------------

LOCK="$MAIN_CHECKOUT/build/ios-device.lock"
mkdir -p "$MAIN_CHECKOUT/build" "$WORKTREE/build"
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  owner_pid=$(sed -n 's/^pid=//p' "$LOCK/owner" 2>/dev/null || true)
  # A lock with no owner file for half a minute was left by a run that died
  # between the mkdir and the write: it would hold every other session forever.
  lock_age=$(($(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s)))
  if { [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; } \
    || { [ -z "$owner_pid" ] && [ "$lock_age" -gt 30 ]; }; then
    echo "    the lock's owner (${owner_pid:-none}) is gone: taking it over" >&2
    rm -rf "$LOCK"
    continue
  fi
  if [ "$waited" -eq 0 ]; then
    echo "    the iPhone is in use, waiting:" >&2
    sed 's/^/      /' "$LOCK/owner" >&2 2>/dev/null || true
  fi
  if [ "$waited" -ge 900 ]; then
    echo "error: the iPhone has been busy for 15 minutes; see $LOCK/owner" >&2
    exit 1
  fi
  sleep 5
  waited=$((waited + 5))
done
printf 'pid=%s\nworktree=%s\nstarted=%s\nscreen=%s\n' \
  "$$" "$WORKTREE" "$(date '+%Y-%m-%d %H:%M:%S')" "$SCREEN" >"$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT

# --- The iPhone ---------------------------------------------------------------

step "Checking $DEVICE"
devices_json=$(mktemp)
xcrun devicectl list devices -q -j "$devices_json" >/dev/null
DEVICE_ID=$(bun -e '
  const { result } = JSON.parse(await Bun.file(process.argv[1]).text())
  const wanted = process.argv[2]
  const device = result.devices.find((d) => d.hardwareProperties.reality === "physical"
    && [d.deviceProperties.name, d.identifier, d.hardwareProperties.udid].includes(wanted))
  if (!device) { console.log(""); process.exit(0) }
  const state = device.connectionProperties.tunnelState
  const ready = device.connectionProperties.pairingState === "paired"
    && device.deviceProperties.developerModeStatus === "enabled"
  console.log(ready && state !== "unavailable" ? device.identifier : "")
' "$devices_json" "$DEVICE")
rm -f "$devices_json"
if [ -z "$DEVICE_ID" ]; then
  echo "error: $DEVICE is not seen, not paired or not in Developer Mode." >&2
  echo "       Plug it in by USB, unlock it, and answer \"Trust\" if it asks." >&2
  exit 1
fi

# --- Build and install --------------------------------------------------------

if [ "${SKIP_BUILD:-}" != 1 ]; then
  step "Building (Debug, generic iOS device)"
  t=$(date +%s)
  packages="${MAIN_DERIVED_DATA:+$MAIN_DERIVED_DATA/SourcePackages}"
  log="$WORKTREE/build/device-capture-build.log"
  # One heavy build at a time on this Mac, Gradle and xcodebuild alike: the
  # shared slot is taken for the build alone and released the moment it ends.
  SLOT="$MAIN_CHECKOUT/build/build-slot-1.lock"
  slot_waited=0
  until mkdir "$SLOT" 2>/dev/null; do
    if [ "$slot_waited" -eq 0 ]; then
      echo "    the build slot is taken, waiting:" >&2
      sed 's/^/      /' "$SLOT/owner" >&2 2>/dev/null || true
    fi
    sleep 15
    slot_waited=$((slot_waited + 15))
  done
  printf 'device-capture.sh pid=%s worktree=%s started=%s\n' \
    "$$" "$WORKTREE" "$(date '+%Y-%m-%d %H:%M:%S')" >"$SLOT/owner"
  trap 'rm -rf "$SLOT" "$LOCK"' EXIT
  if ! xcodebuild -jobs 4 -project ios/Shiori.xcodeproj -scheme Shiori \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    ${packages:+-clonedSourcePackagesDirPath "$packages"} \
    -allowProvisioningUpdates \
    SWIFT_ENABLE_EXPLICIT_MODULES=NO \
    build >"$log" 2>&1; then
    rm -rf "$SLOT"
    grep -E "error:" "$log" | head -20 >&2
    echo "error: build failed, see $log" >&2
    exit 1
  fi
  rm -rf "$SLOT"
  trap 'rm -rf "$LOCK"' EXIT
  elapsed "$t"
fi
[ -d "$APP" ] || { echo "error: no build at $APP" >&2; exit 1; }
# A worktree without the gitignored Firebase config builds an app that dies at
# launch: never put that on the reader's phone.
if [ ! -f "$APP/GoogleService-Info.plist" ]; then
  echo "error: the build has no GoogleService-Info.plist (copy ios/Shiori/GoogleService-Info.plist" >&2
  echo "       from the main checkout, then build again); nothing installed." >&2
  exit 1
fi

# Installs only when the build on the phone is this one. The stamp is shared by
# every worktree: another session's install replaces it, and this run installs
# its own build again rather than capturing theirs.
stamp="$MAIN_CHECKOUT/build/ios-device.installed"
digest="$WORKTREE $(shasum -a 256 "$APP/Shiori" "$APP/Info.plist" | shasum -a 256 | cut -c1-16)"
if [ "$(cat "$stamp" 2>/dev/null)" != "$digest" ]; then
  step "Installing (keeps the account and its data)"
  t=$(date +%s)
  xcrun devicectl device install app -q --device "$DEVICE_ID" "$APP" >/dev/null
  echo "$digest" >"$stamp"
  elapsed "$t"
fi

# --- The covers ---------------------------------------------------------------

# The showcase reads its covers off disk; the iPhone gets its own copy once.
files_json=$(mktemp)
xcrun devicectl device info files -q --device "$DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
  --subdirectory "$COVERS_ON_DEVICE" -j "$files_json" >/dev/null 2>&1 || true
on_device=$(bun -e '
  try {
    const { result } = JSON.parse(await Bun.file(process.argv[1]).text())
    console.log((result.files ?? []).filter((f) => f.name?.endsWith(".jpg") || f.relativePath?.endsWith(".jpg")).length)
  } catch { console.log(0) }
' "$files_json")
rm -f "$files_json"
on_mac=$(find screenshots/covers -name '*.jpg' | wc -l | tr -d ' ')
if [ "$on_device" -lt "$on_mac" ]; then
  step "Copying the showcase covers ($on_mac files)"
  t=$(date +%s)
  xcrun devicectl device copy to -q --device "$DEVICE_ID" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
    --source screenshots/covers/. --destination "$COVERS_ON_DEVICE" >/dev/null
  elapsed "$t"
fi

# --- Capture ------------------------------------------------------------------

lock_json=$(mktemp)
xcrun devicectl device info lockState -q --device "$DEVICE_ID" -j "$lock_json" >/dev/null
locked=$(bun -e '
  const { result } = JSON.parse(await Bun.file(process.argv[1]).text())
  console.log(result.passcodeRequired ? "yes" : "no")
' "$lock_json")
rm -f "$lock_json"
if [ "$locked" = yes ]; then
  echo "error: $DEVICE is locked. Unlock it (Face ID) and run again;" >&2
  echo "       Settings > Display & Brightness > Auto-Lock > Never keeps it so." >&2
  exit 1
fi

step "Opening $SCREEN${APPEARANCE:+ ($APPEARANCE)} from the showcase"
t=$(date +%s)
launch_json=$(mktemp)
args=(-showcase "$SCREEN_FLAG" "$SCREEN")
[ -n "$APPEARANCE" ] && args+=(-showcase-appearance "$APPEARANCE")
xcrun devicectl device process launch -q --device "$DEVICE_ID" --terminate-existing \
  -j "$launch_json" "$BUNDLE_ID" -- "${args[@]}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} >/dev/null
pid=$(bun -e '
  const { result } = JSON.parse(await Bun.file(process.argv[1]).text())
  console.log(result.process?.processIdentifier ?? "")
' "$launch_json")
rm -f "$launch_json"
sleep "$SETTLE"

mkdir -p "$(dirname "$OUT")"
xcrun devicectl device capture screenshot -q --device "$DEVICE_ID" --destination "$OUT" >/dev/null
elapsed "$t"

# The showcase leaves the screen; the reader's own app is back on the next opening.
[ -n "$pid" ] && xcrun devicectl device process terminate -q --device "$DEVICE_ID" --pid "$pid" >/dev/null 2>&1 || true

echo "$OUT"
