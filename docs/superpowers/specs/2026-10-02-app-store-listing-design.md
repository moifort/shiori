# App Store listing — design

Shiori's product page goes from empty to submittable: six marketing panels, the listing text,
the two subscriptions, and a release that refuses to submit a version without its panels.
Everything structural is transposed from Vinarium (`../vinarium/docs/screenshots.md`).

## State on 2026-10-02

Read through the App Store Connect API:

- Version 1.0 is `PREPARE_FOR_SUBMISSION`, listing empty: no subtitle, description, keywords,
  category, age rating, privacy URL or screenshots.
- Group "Shiori Premium" holds the yearly subscription only, `MISSING_METADATA`: no price, no
  free trial, no localization, no review screenshot. The monthly one does not exist.
- `release-ios.yml` already archives, uploads, attaches the build, writes "What's New" and
  submits with automatic release on a `ios-v*` tag. `deliver` runs without `skip_metadata`, so
  a versioned metadata directory is pushed with every release.

## Decisions

| | Choice | Why |
|---|---|---|
| Data on screen | Swift fixtures inside the app, behind a DEBUG-only `-showcase` launch argument | Chosen over a seeded dev server: no backend to start |
| Books | Real titles with their published covers | The credible choice, and what every book app shows |
| Panels | Six, scan first; the paywall is not one of them | The first three show in search results; prices are listed under In-App Purchases anyway |
| Where it runs | Captures, panels and their upload run on the Mac, never in CI | A workflow that boots a simulator costs twenty minutes per release for images that did not change |
| Language | French only | The app has no string catalogue yet; the language stays a parameter |
| Third-party content | Declared as not used | A reader may give any cover URL of their own |
| User-generated content | Declared as not present | Notes and opinions are seen by invited friends only |

## 1. Captures

### The showcase mode

`ios/Shiori/Shared/Showcase.swift`, wrapped in `#if DEBUG` like `UITestEnvironment`, so the
Release archive carries none of it.

- `Showcase.isOn` reads `-showcase` from the launch arguments.
- `AuthRoot` shows the signed-in app straight away: no Apple sign-in, no onboarding route, no
  support-gate request, a demo first name.
- Every read the captured screens make starts with an early return of fixture data:
  `HomeAPI.dashboard`, `AwaitedAPI.awaited`, `DiscoverAPI.discovery`, `FriendsAPI.recentFavorites`,
  `FriendsAPI.picks`, `FriendsAPI.friends`, `FriendsAPI.myShelf`, `LibraryAPI.libraryPage`,
  `SeriesAPI.mySeriesPage`, `SeriesAPI.followedSeries`, `BookAPI.book`, plus the subscription
  state the gate and the paywall read. Nothing else is touched.
- The snapshot caches (`SnapshotCache`) are bypassed in showcase mode, so a capture never shows a
  previous session's library.

### The fixture library

One dataset, `Showcase.library`: some forty real books — novels, French BD, manga series in
progress — with statuses, ratings, notes and reading dates spread over two years, a few series
with an announced volume, and two friends with their recent hearts.

The dashboard is **computed from that list** (books per year, pages per month, genres, series
progress, averages), never typed by hand, so the home screen cannot contradict the library by
construction. The app has no unit-test target, and one is not added for this.

### Covers

`scripts/showcase-covers.ts`, modelled on `launch-covers.ts`, downloads each fixture's cover
once into `screenshots/covers/`, committed. The source is the iTunes Search API, which serves
the French editions' artwork without a key or a quota: Open Library knows few recent French
editions, and Google Books refuses anonymous callers once its daily quota is spent. The fixtures name them by `file://`
URL built from `#filePath`: the simulator reads the Mac's disk, and the app bundle gains nothing.

### The paywall

StoreKit does not reliably hand products to an app launched by a UI test, so `PremiumSheet` is
split atomic-design style: `PremiumPage` takes plain offers (name, price, period, trial) and the
sheet maps StoreKit's `Product` onto them. The showcase hands the page 1,99 € a month and
17,99 € a year with a one-month trial. This capture is for App Review only.

### The scan

The capture is the review of a scanned cover (`ScanReviewPage`) fed a showcase result: the
simulator has no camera, and an empty viewfinder sells nothing. The test reaches it the way a
reader does, through the add sheet's last photo, which the script puts in the simulator's
library (`simctl addmedia`, after opening Photos once: on a fresh simulator it otherwise waits
forever).

### Running it

`scripts/screenshots.sh [lang]` builds with a session-unique derived-data path
(`SWIFT_ENABLE_EXPLICIT_MODULES=NO`, `DEVELOPER_DIR` set) and runs `ShioriUITests/ScreenshotTest`
on an iPhone 17 Pro Max (1320×2868, the 6.9" size). The test navigates by accessibility
identifier, waits for an identifier that only exists once a screen has its data, and writes
seven PNGs into `screenshots/captures/fr/`: `01-scan` to `06-shared`, and `paywall`. The script
fails when fewer than seven files come out. French is hard-wired until the app has a string
catalogue.

## 2. Panels

Eight panels on a very light grey (#F2F2F4):

| Panel | What it shows | Caption |
|---|---|---|
| 01 · 02 | One photograph cut in two: the Hypérion paperback lying across the cut, a hand scanning it, the phone showing its record | Scannez… · …Shiori fait le reste |
| 03 | A drawn iPhone: the mosaic | Livres et audio ! |
| 04 | A drawn iPhone: the dashboard | Des analytics détaillés |
| 05 | A drawn iPhone: the sagas | Suivi de vos séries préférées |
| 06 | A drawn iPhone: One Piece's page and its next volume | Être averti des sorties et disponibilités |
| 07 | A drawn iPhone: Découvrir | Découvrez vos nouveaux coups de cœur |
| 08 | Two friends' hands, each phone on the Partagé page, one held upside down | Partagez votre bibliothèque avec vos proches |

**The app alone** (03–07) is an iPhone 17 Pro Max drawn by `device-panel.swift` to the
device's own geometry — titanium band, black border, Dynamic Island, side buttons — so the
capture fills the screen to the pixel, on the grey. Hands added nothing there.

**The photographs** (01–02, 08) are drawn by the image model with each phone's display in
flat chroma-key green and the book's cover in magenta; it is never asked for the app or the
cover, whose text it garbles. `composite-mockup.swift` finds each keyed region, takes its
corners from straight lines fitted along its four edges (its extreme points sit inside the
rounded corners and left a strip of screen uncovered; a book's cover, which the phone may hide in part, is taken square from where most of each side shows), widens the photograph around the
phones until their screens have the capture's proportions (the model draws phones narrower
than an iPhone whatever it is told), and fits the capture in perspective, never stretched,
keeping the photograph wherever a finger or the bezel crosses it.

`finish-panel.swift` fits each photograph to the panel — or to two, for the scan — evens its
backdrop out to the exact grey, zooms in where the model drew the phones smaller than asked,
and sets the captions in the system font.

Scenes are drawn at 2K and cached as JPEG in `screenshots/appstore/scenes/`, committed; only
`--regenerate <scene>` calls the model (`NITRO_GOOGLE_API_KEY`, a local-only key).

### Upload

`bun scripts/upload-appstore-panels.ts`, run on the Mac before the tag. It refuses a version
that is no longer editable, empties the 6.9" set, uploads the six panels in filename order, then
counts what the store holds and fails on a mismatch.

## 3. Listing, subscriptions, release

### The listing

`infra/fastlane/metadata/fr-FR/` and its siblings, pushed by `deliver` in the `submit` lane:

| File | Content |
|---|---|
| `name.txt` | Shiori |
| `subtitle.txt` | Scannez et suivez vos lectures |
| `description.txt` | Hook, FONCTIONNALITÉS, PREMIUM — Vinarium's structure |
| `keywords.txt` | ≤ 100 characters, no competitor names |
| `promotional_text.txt` | One sentence |
| `privacy_url.txt` | https://moifort.github.io/shiori/ |
| `support_url.txt` | https://github.com/moifort/shiori |
| `../primary_category.txt` | BOOKS |
| `../secondary_category.txt` | LIFESTYLE |
| `../copyright.txt` | 2026 Polyforms |
| `../review_information/*` | Contact, no demo account, notes naming the way to the paywall |
| `infra/fastlane/app_rating_config.json` | Every descriptor at none: 4+ |

`release_notes.txt` stays generated by the release workflow and gitignored.

### Subscriptions

`scripts/appstore-subscriptions.ts`, idempotent, run once from the Mac with the team API key:

| Product | Price (France, equalized elsewhere) | Offer | Localized name / description |
|---|---|---|---|
| `…premium.monthly` (created) | 1,99 € | — | Premium mensuel · Scans illimités et séries complètes, pour un mois |
| `…premium.yearly` (completed) | 17,99 € | one free month | Premium annuel · Scans illimités et séries complètes, pour un an |

Each gets the paywall capture as review screenshot and a review note. They go to review with
version 1.0.

### Release guard

The `submit` lane checks, before `deliver`, that the version holds six 6.9" screenshots, and
fails with the command to run if not.

### Manual

App Privacy has no official API. The answers are transposed from Vinarium minus precise location
(to be confirmed against the code) and entered in App Store Connect through the browser, with
the user's go-ahead at that moment.

## Testing

- A Release build contains no `Showcase` symbol.
- The seven captures and six panels are sent to the user for approval before any upload.
- The upload and subscription scripts end by reading back what the store holds.
