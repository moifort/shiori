/**
 * Oldest iOS build the currently deployed GraphQL schema still supports.
 *
 * The build number is `CFBundleVersion`, set by CI to `git rev-list --count HEAD`
 * at tag time, so it grows monotonically with every commit. Builds below this
 * floor are shown a blocking "update required" screen by the app (see
 * `GET /app-config` and `AppSupportGate.swift`).
 *
 * Bump it ONLY when shipping a breaking schema change, to the build of the iOS
 * release that ships alongside it (`git rev-list --count HEAD` + 1 before the
 * bump commit) — see docs/api-evolution.md for the full runbook. Users on older
 * builds stay blocked until that release clears App Store review.
 */
export const MINIMUM_SUPPORTED_IOS_BUILD = 1

/** Direct App Store link (unlisted distribution), opened by the update screen. */
export const APP_STORE_URL = 'https://apps.apple.com/app/id6789688303'
