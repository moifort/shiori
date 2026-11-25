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

## Lint

Android Lint runs before every commit that touches `android/`, with the unit tests and the debug
build, and in the Build Android and Release Android workflows; an error fails them.

```bash
cd android && ./gradlew :app:lintDebug :app:testDebugUnitTest :app:assembleDebug
```

The report is `android/app/build/reports/lint-results-debug.txt`. An error is fixed at its
cause: no baseline file. A check wrong for this app is disabled alone in the `lint { }` block of
`app/build.gradle.kts`, with a comment saying why; today only `NonObservableLocale`, since a
language change recreates the activity. Media3's unstable APIs are opted into in
`AudiblePlayer.kt` alone (`@file:OptIn(UnstableApi::class)`).

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

A fade that changes — disabled, in progress, set aside — is `graphicsLayer { alpha = … }`, never
`Modifier.alpha(…)`: the latter drops its layer at 1, and in a sheet the reshaped node stopped
drawing (the portrait picker's confirm button vanished once a face was picked, 2026-11-25).
`scripts/check-android-components.ts` refuses it in components.

The design conventions of [ios-guide.md](ios-guide.md#design-conventions) hold on Android
word for word — large cards at one fixed height, a card never growing past its frame, the date
box on every Actualité card, a series' countdown over its name, and the rest: a port follows them, and
a rule added there is a rule here.

## Checking a screen

A debug build opens a page from its fixtures:

```bash
adb shell am start -n com.polyforms.shiori.app/com.polyforms.shiori.MainActivity --es preview book
```

and the App Store fixtures with `--ez showcase true`. The app's language is set per app:
`adb shell cmd locale set-app-locales com.polyforms.shiori.app --locales fr-FR`.
