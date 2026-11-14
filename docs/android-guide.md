# Android Guide

The Android app is a mirror of the iOS app. iOS is where features are designed, built and
validated; Android follows, and catches up with every iOS change before each release
(CLAUDE.md, Workflow rule 10). `android/` is never edited during feature or fix work: the whole
port happens at release time, is tested by the user on their Pixel 8, and the tag is cut only
after their validation. The design is
[superpowers/specs/2026-11-06-android-mirror-design.md](superpowers/specs/2026-11-06-android-mirror-design.md).

## Stack

- **Kotlin, Jetpack Compose**, minSdk 29, target and compile SDK 37, AGP 9, JDK 21
- **Apollo Kotlin**, reading the iOS app's own operation documents
  (`ios/Shiori/Features/*/GraphQL/*.graphql`) and `shared/schema.graphql`. The only
  Android-only operations live in `android/app/src/main/graphql/` (the Play purchase sync).
- **Firebase Auth** with Google sign-in, **Play Billing** for Premium, **FCM** for alerts,
  **Sentry** (release builds with a DSN), **Coil** for covers.
- One emulator, `Pixel_9_Pro` (Android 37, Play Store image), created once and reused.

## The mirror

Every Swift file has a Kotlin file of the same name in the same place:

| iOS | Android |
|---|---|
| `ios/Shiori/Shared/…` | `android/app/src/main/java/com/polyforms/shiori/shared/…` |
| `ios/Shiori/Features/Book/BookScreen.swift` | `…/features/book/BookScreen.kt` |
| `components/{organisms,pages}/X.swift` | `components/{organisms,pages}/X.kt` |
| `{Domain}Client` struct of closures, `.live` | `{Domain}Client` interface, `live` |
| `@Observable` view model | a class of `mutableStateOf` fields, suspend actions |
| `NotificationCenter` `.shioriDataDidChange` | `DataChanges.notices` (a `SharedFlow`) |
| `navigationDestination(item:)` | `currentNavigator.push { Screen(…) }` |
| `.sheet` | `ShioriSheet`, `.fullScreenCover` → `FullScreenCover` |
| SF Symbol names | the same names, through `Symbol("…")` (`styles/Symbols.kt`) |
| `String(localized: "À lire")` | `L("À lire")` — same French key, same catalogue |

The one rule of the iOS guide holds: a composable is pure (renders from values) or connected
(the `…Screen` that owns its view model). Porting a diff is reading the Swift file and editing
the Kotlin file of the same name.

## Components

Atomic design, as on iOS: `shared/components/{atoms,molecules,organisms,styles}` and, in each
feature, `components/{molecules,organisms,pages}`. Everything under a `components/` folder is
pure: it never calls `GraphQLClient` or a client's `live`, holds no view model, never touches
`DataChanges`, `AppContext` or `PushRegistrar`; the `…Screen` beside the folder does.

Every file declaring a composable ends with a `@Preview` drawn inside `PreviewSurface` (the
theme, a navigator, the grouped background) from `DebugFixtures`, never from the server.
`bun scripts/check-android-components.ts` enforces both rules, and the Build Android workflow
runs it.

## Copy

Strings come from the iOS catalogue: `bun scripts/android-strings.ts` writes
`assets/strings.json`, looked up by the French key. Swift interpolations keep their catalogue
key (`L("%lld pages", n)`, `L("Sort le %@", day)`). The few sentences only Android says
(Google where iOS says Apple, Play where it says the App Store) live in
`assets/strings.android.json`, French key and English translation, kept by hand.

## Look

The iOS system palette (`styles/Theme.kt`), Apple's text sizes, glass approximated by
translucent fills (`styles/Glass.kt`), the floating tab bar and the floating bar of a pushed
screen. Android conventions win only where the platform imposes them: the back gesture,
system bars, the share sheet, permissions, date pickers.

## Checking a screen

A debug build opens a page from its fixtures:

```bash
adb shell am start -n com.polyforms.shiori.app/com.polyforms.shiori.MainActivity --es preview book
```

and the App Store fixtures with `--ez showcase true`. The app's language is set per app:
`adb shell cmd locale set-app-locales com.polyforms.shiori.app --locales fr-FR`.
