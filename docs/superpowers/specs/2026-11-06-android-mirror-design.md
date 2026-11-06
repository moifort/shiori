# Shiori for Android — a mirror of the iOS app

## Intent

Shiori ships on Android as a public app on Google Play, freemium like on iOS. The iOS app stays
the place where features are designed, built and validated; Android follows it. The first pass
ports the whole app as it stands today. After that, every App Store release is preceded by an
Android catch-up: everything that changed on iOS since the previous release is ported, and both
apps ship the same version.

## Goals

- A native Android app (Kotlin, Jetpack Compose) that offers every iOS feature, screen for screen:
  Accueil, Bibliothèque, Découvrir, Actualités, Amis, scan, import (Kindle, Audible, Goodreads…),
  book, series, author and narrator pages, wishlist, settings, onboarding, subscription, admin.
- The same look as iOS — dark, cover-led, white-on-glass labels, the board's components — not a
  stock Material app. Android conventions win only where the platform imposes them: system back
  gesture, status/navigation bars, share sheet, permissions, notification channels.
- The same server and the same accounts: Android talks to the same GraphQL API, with the same
  operation documents, and a reader who signs in with Apple on both phones sees one library.
- Freemium on Google Play: the same two subscriptions (yearly, monthly), the same free tier and
  scan allowance, Premium recognised by the server whichever store sold it.
- A repeatable release ritual: before every App Store release, port the diff, build, check
  screens on the emulator, ship both.

## Non-goals

- No Kotlin Multiplatform or shared UI code with iOS. iOS stays SwiftUI; the shared layer is the
  GraphQL schema and the operation documents.
- No Android-only features. Anything new is designed on iOS (and on the board) first.
- No tablet- or ChromeOS-specific layouts in the first pass (phones, plus foldables where the
  iOS app already handles the iPhone Duo fold).
- No cross-store subscription transfer: a Premium bought on the App Store is Premium on Android
  because the account is the same, not because Google knows about it.

## Anti-goals

- An Android app that drifts: a feature validated on iOS and released without its Android port.
- A second source of truth for copy: Android strings come from the iOS catalogue
  (`Localizable.xcstrings`), French and English, generated, never retyped by hand.
- Paying twice for AI: Android never calls Gemini or Claude directly; everything goes through
  the server as on iOS, so the cost rules in CLAUDE.md are unchanged.

## Constraints

- Public release on Google Play requires a Play Console developer account (the user's). A
  **personal** account created after November 2023 must run a closed test with at least 12
  testers for 14 days before it can publish to production; an **organisation** account
  (Polyforms, with a D-U-N-S number) does not.
- The GraphQL schema is not versioned (docs/api-evolution.md): Android builds join the same
  deprecation rule. `MINIMUM_SUPPORTED_IOS_BUILD` gains an Android twin.
- Every server change follows the existing domain rules (branded types, outcomes, flat
  collections, tests in three suffixes).

## How it is built

### Stack

| iOS | Android |
|---|---|
| SwiftUI, iOS 26 | Kotlin, Jetpack Compose, minSdk 29 (Android 10), target the latest SDK |
| Apollo iOS, operations in `Features/*/GraphQL/*.graphql` | Apollo Kotlin, reading the **same** `.graphql` files from `ios/` |
| Firebase Auth, Sign in with Apple | Firebase Auth: Sign in with Apple (web flow) **and Google** |
| StoreKit 2, `syncEntitlement(signedTransaction)` | Play Billing, `syncPlayEntitlement(purchaseToken)` |
| APNs (`registerDevice`) | FCM (`registerDevice` with a new `FCM` environment) |
| Sentry, Firebase Analytics | Sentry Android, Firebase Analytics |
| Charts | Compose Canvas |
| Share extension | `ACTION_SEND` intent filter |
| `UIViewControllerRepresentable` wrappers | `Shared/Platform` equivalents: CameraX, WebView, contacts, photo picker |

### Layout

`android/` at the repository root, one Gradle app module, mirroring `ios/Shiori/`:

```
android/app/src/main/java/com/polyforms/shiori/
├── shared/{components/{atoms,molecules,organisms,styles}, book, platform, shell, …}
└── features/{domain}/
    ├── {Feature}Screen.kt      connected: ViewModel, effects, navigation
    ├── {Feature}ViewModel.kt
    ├── {Domain}Client.kt       interface of suspend functions, live and preview
    ├── {Domain}Api.kt          Apollo operations → app models
    ├── {Domain}Models.kt
    ├── {Domain}Fixtures.kt
    └── components/{organisms,pages}
```

The iOS guide's one rule carries over unchanged: a composable is pure (renders from values in a
`@Preview`) or connected (`…Screen`, owns the ViewModel). File and type names match iOS one to
one, so porting a diff is reading the Swift file and editing the Kotlin file of the same name.
`docs/android-guide.md` records the mapping and the Android-specific rules.

### Server changes

1. **Google sign-in**: enable the Google provider in Identity Platform (Terraform), register the
   Android app in Firebase (`google_firebase_android_app`, SHA fingerprints of the debug, upload
   and Play signing keys).
2. **Play subscriptions**: the entitlement records which store sold it (`appStore` |
   `googlePlay`). A new mutation verifies a purchase token against the Google Play Developer API
   (service account with Play Console access) and checks the purchase's obfuscated account id,
   derived from the user id like `appAccountToken`. `planOf` is unchanged. Renewals are picked up
   the way iOS picks them up today (the app syncs on launch); Real-time developer notifications
   are a later addition, not part of this pass.
3. **Push**: `PushEnvironment` gains `FCM`; the notification sender routes a device to APNs or
   FCM by its environment. Alert content is unchanged.
4. **Update gate**: `app-config` returns a Play Store URL and a minimum Android build.

### Distribution

A GitHub Actions workflow builds a signed App Bundle on an `android-v*` tag and uploads it to
Play (internal track first, promoted by hand), as `release-ios.yml` does for TestFlight. The
store listing (French and English) is derived from the App Store one.

### Release ritual

Written into CLAUDE.md and `docs/android-guide.md`: when a release is asked for, before tagging
`ios-v*`, list the iOS commits since the previous release, port each one to Android, build, run
the Android tests, capture the changed screens on the emulator, then cut both releases with the
same version number.

## Order of work

1. Tooling (JDK, Android SDK, one emulator image), project skeleton, Apollo, Firebase, auth.
2. Shell: launch curtain, tabs, update gate, design system (atoms, molecules, colours, covers).
3. Domains, in dependency order: Book and Library, Series, Authors, Narrators, Home, Search,
   Wishlist, Scan, Import, News, Friends, Discover, Settings, Onboarding, Subscription, Admin.
4. Server: Google sign-in, Play entitlement, FCM, Android update gate.
5. CI and Play listing.

Each domain is a commit (or a few), checked by Android unit tests on its ViewModel and an
emulator screenshot of its screens.

## Left to the builder

- Library choices beyond the stack table (image loading: Coil; navigation: Navigation Compose;
  DI: plain constructor injection, as iOS uses `init(client:)`).
- How glass and blur effects are approximated below Android 12, where `RenderEffect` is absent.
- Internal structure of the strings generator from `Localizable.xcstrings` to `strings.xml`.
