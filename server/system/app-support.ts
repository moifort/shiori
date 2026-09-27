/**
 * Oldest iOS build the currently deployed GraphQL schema still supports.
 *
 * The build number is `CFBundleVersion`, set by CI to `git rev-list --count HEAD`
 * at tag time, so it grows monotonically with every commit. Builds below this
 * floor are shown a blocking "update required" screen by the app (see
 * `GET /app-config` and `AppSupportGate.swift`).
 *
 * Raised only by the removal commit of the deprecation routine, to the value
 * `bun run deprecations` proposes: a build that no longer asks for what is
 * removed, on the App Store for two weeks. The Deploy workflow refuses a floor
 * above the build on sale — see docs/api-evolution.md.
 */
export const MINIMUM_SUPPORTED_IOS_BUILD = 1

/** Direct App Store link, opened by the update screen. */
export const APP_STORE_URL = 'https://apps.apple.com/app/id6811938144'
