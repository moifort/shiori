# Shiori 栞 — design

> Written 2026.09.14. Covers batches 1 and 2 of the roadmap: scan, book record, library,
> rating, reading note, and series. Batches 3 to 6 (sharing, release alerts, Kindle import,
> AI suggestions) are out of scope here and live in [roadmap.md](../../roadmap.md).

Shiori (栞, "bookmark") is an iOS app that turns a photo of a book cover into a catalogued,
rated, annotated book record, and groups a library into series.

It is the second app built on the Vinarium stack. Everything structural — infrastructure,
CI/CD, domain architecture, AI pipeline, freemium mechanics — is transposed from
`../vinarium` rather than invented. This document records what is copied, what is adapted,
and the few places where books genuinely differ from bottles.

## 1. Product scope

A user photographs a book cover. Gemini reads the cover, a second grounded call enriches it
from the web, and the user validates the resulting record before it is saved. The book lands
in their library with one of three reading statuses, and can carry a five-star rating and a
free-text note. Books belonging to a series are grouped together.

### In scope

- Cover-photo scan, AI extraction, AI enrichment, user review before save
- Manual add, without a photo and without an AI call
- Library: three reading statuses, five-star rating, free-text note
- `hidden` flag on every book, excluding it from any future sharing
- Series: shared catalogue, grouping in the library, series screen, related works
- Freemium: metered scans, StoreKit subscription, welcome credits
- French and English

### Out of scope

Sharing between users, release notifications, Kindle import, and AI reading suggestions are
batches 3 to 6. Only the `hidden` flag is built now, because adding a boolean to records
already in production would cost a migration.

## 2. Naming and identifiers

| | Value |
|---|---|
| App name | Shiori |
| Bundle ID | `com.polyforms.shiori.app` |
| UI tests bundle ID | `com.shiori.app.uitests` |
| GCP project | `shiori-polyforms` |
| Xcode project | `ios/Shiori.xcodeproj` |
| Apollo namespace | `ShioriGraphQL` |
| Release tag | `ios-v<version>` |

## 3. Architecture

### 3.1 The central decision: everything is per user

In Vinarium a `beverage` belongs to exactly one user. Shiori keeps that model: **a book
record is private, owned by one user, and never merged with anyone else's.** Two users who
scan the same novel create two independent records.

This was chosen over a shared work catalogue. A shared catalogue would deduplicate records
and cut AI cost, but it requires canonical identity resolution across editions, and it
places the user's library in a globally readable collection. Ownership and privacy win;
the duplicated AI cost is bounded by the scan cache and the per-user scan quota.

Consequence: there is no separate "library entry" entity. Reading status, rating, note and
dates are fields **on the book record itself**, exactly as a tasting note sits on a
`beverage`.

### 3.2 The one exception: the series catalogue is shared

The list of volumes in a saga ("The Wheel of Time has 14 volumes, here are their titles") is
a public fact. It contains no personal data and carries no reference to any user, so it is
stored once in a global `series` collection, in the same spirit as Vinarium's `scan-cache`.

This divides the catalogue's AI cost by the number of readers, and gives batch 4 a single
row per saga to watch for release dates instead of one per reader.

**The shared catalogue is never exposed through sharing.** When batch 3 lands, a shared
library shows books, never series.

### 3.3 Firestore layout

```
users/{userId}/books/{bookId}     private — the book record, including status, rating, note
series/{seriesKey}                global — public catalogue, no user reference
scan-cache/{imageHash}_{lang}     global — transposed from Vinarium
```

### 3.4 Server domains

| Domain | Origin |
|---|---|
| `book` | new — the core record and its reading state |
| `series` | new — the shared catalogue and the grouping rules |
| `scan` | adapted from Vinarium; prompts and response schemas rewritten for books |
| `user`, `quota`, `entitlement`, `changelog`, `admin`, `portability`, `attachment`, `search`, `home` | transposed from Vinarium |

Vinarium's `household`, `gift`, `tasting`, `journal`, `recommendation` and `cellar` domains
are not carried over: they belong to later batches or have no book equivalent.

Every domain follows `docs/domain-guide.md` from Vinarium: `types.ts`, `primitives.ts`,
`command.ts` (`XxxCommand` namespace), `query.ts` (`XxxQuery` namespace), optional
`business-rules.ts` / `use-case.ts`, and `infrastructure/{repository.ts, graphql/}`.
Repositories are bare functions, private to their domain.

### 3.5 Infrastructure

Transposed wholesale onto a fresh GCP project: Terraform (`infra/`), Cloud Functions gen 2
in `europe-west3`, Firestore `eur3`, Firebase Auth with Sign in with Apple only, Secret
Manager, Sentry, Cloud Scheduler for the daily admin metrics refresh, and the eight GitHub
Actions workflows. Bun as the only runtime, Biome as the formatter and linter, Renovate for
dependencies.

Migrations are forward-only and sequential, tracked in `migration-meta`, triggered by
`POST /admin/migrate`.

## 4. The book record

### 4.1 Fields filled by AI

Title, authors, publisher, first publication year, synopsis, genres, page count, ISBN-13 of
the edition found, language, series name and volume number.

### 4.2 Fields filled by the user

Reading status, star rating, free-text note, `hidden` flag, and three dates: added,
started, finished.

### 4.3 Reading status

Three values: `to-read`, `reading`, `read`. No page-level progress tracking — it demands
constant manual input to stay truthful, and a reliable page count per edition that the AI
estimates poorly.

### 4.4 Rating

Whole stars, one to five. Half stars double the value space without adding discernment and
shrink the touch target.

### 4.5 The cover is the user's own photo

Grounding cannot return a reliable image URL, and the real cover is already in hand: the
photo just taken. It is stored in Cloud Storage through the `attachment` domain and the
bucket already described in Vinarium's `infra/storage.tf`. No external dependency, no dead
links.

A book added manually or from a series catalogue has no photo. The UI renders a typographic
placeholder built from title and author.

### 4.6 Branded types

`ts-brand` plus Zod constructors in `primitives.ts`, one GraphQL scalar per brand:
`BookId`, `SeriesId`, `Isbn13`, `StarRating`, `VolumeNumber`, `BookTitle`, `AuthorName`,
`ReadingNote`.

## 5. The scan pipeline

Transposed from `server/domain/scan/index.ts`, with one extra step. All three calls use
Gemini 2.5 Flash.

**Step 1 — Vision.** The cover photo in, a strict `responseSchema` out: `recognized`, title,
authors, publisher if legible, and any series and volume mention printed on the cover — book
covers state "Volume 3" far more often than wine labels state anything useful. As in
Vinarium, `recognized: false` returns immediately and is **not** cached, so a bad photo can
be retaken.

**Step 2 — Enrichment.** Gemini with `tools: [{ google_search: {} }]`. From title and author,
grounding fills synopsis, first publication year, genres, page count, ISBN-13, and above all
**series membership and volume number** — which the cover conveys badly or not at all.

**Step 3 — Series catalogue.** Only when step 2 identified a series absent from the global
`series` collection. Returns the ordered list of volumes: number, title, publication year,
and kind. A standalone book, or a saga already catalogued, skips this step entirely.

The cache is Vinarium's: SHA-256 of the image, keyed by language, best-effort write.

`usageMetadata` is captured from every call and fed to the admin cost metrics, so the quota
and the price can be recalibrated against measured tokens.

### 5.1 The review screen

Gemini proposes, the user validates before the record is saved. This catches a misread cover
and is the safety net against a wrong record. It is also where the user picks the reading
status the book starts in.

## 6. Series

### 6.1 The catalogue

A `series` document holds the saga's name, its author, a short description, and an ordered
list of volumes. Each volume carries a title, a publication year, an optional number, and a
**kind**: `main`, `prequel`, `spin-off`, `novella`, `companion`. The number is optional
because a spin-off has none.

The catalogue stores **publication order**, which is a verifiable fact. Reading order differs
on many sagas (Narnia, Dune, Discworld) and is a matter of opinion that grounding restitutes
inconsistently.

The response schema forces Gemini to classify each volume's kind before describing it, on the
model of Vinarium's step 0, which is what makes the output reliable.

### 6.2 In the library — grouping only

The library contains **only the user's own books**, never a proposal. When several of them
belong to one series they are grouped into an iOS section named after the series, ordered by
volume number, with related works after the numbered volumes. Books without a series stay in
a plain list.

The section header shows the series name and a state badge: **in progress**, or **complete**
when every published volume in the catalogue has been read. No counter — the count of owned
volumes against total volumes is noise in a list whose purpose is to show what the user owns.

### 6.3 On the book screen — a recommendations section

Below the book's own information, a section listing **the other volumes of the series**. This
is zero-cost recommendation: the catalogue is already in the database. Each volume the user
does not own carries an "add to my reading list" action, which creates a record with no photo
and no AI call. The series name is tappable and leads to the series screen.

### 6.4 The series screen — the full catalogue

A short description of the saga, its state, then every volume in one of three states: in the
user's library (with status and rating), absent (a proposal), or forthcoming when the
publication year is in the future. Main volumes in order, then a "Related works" block.

## 7. Freemium

The Vinarium model: **AI scans are metered, everything else is free and unlimited.** Adding
a book by hand, adding from a series catalogue, the series catalogue call itself, editing a
record, rating, annotating — none of these consume a credit.

| | Free | Premium — €2.99 / month · €24.99 / year |
|---|---|---|
| Scans | 5 / month | 100 / month |
| Welcome credits | 50, once, at signup | — |
| Everything else | unlimited | unlimited |

The welcome allowance is 50 rather than Vinarium's 20 because books are catalogued in bursts:
a new user empties a shelf in one evening. Hitting the wall during the first session is the
worst possible moment.

These numbers are provisional and will be recalibrated against measured `usageMetadata`, per
Vinarium's `docs/freemium-economics.md`. The series catalogue call is shared across all
users, so it is not metered.

## 8. GraphQL API

Apollo Server plus Pothos, single endpoint `POST /graphql`. The schema is not versioned:
breaking changes ride the force-update gate (`MINIMUM_SUPPORTED_IOS_BUILD`), shipping backend
and iOS together.

**Queries** — `library`, `book`, `series`, `mySeries`, `home`, `quota`, `me`, `changelog`.

**Mutations** — `scanBook`, `addBook`, `addBookFromSeries`, `updateBook`, `rateBook`,
`setReadingStatus`, `setBookNote`, `setBookHidden`, `deleteBook`.

Commands return bare string-literal outcomes (`'not-found' as const`) or the domain value;
resolvers map them with `match().exhaustive()`.

### 8.1 The N+1 constraint

A 300-book library grouped by series must never read one series document per row. The
`series` field on library rows resolves through a per-request loader, on the model of
Vinarium's `server/domain/shared/graphql/loaders.ts`. Integration tests assert the read
budget with the split `fake.docReads` / `fake.queryReads`.

## 9. iOS

Target iOS 26.0, Swift 6 strict concurrency, `@MainActor` on view models, `Sendable` on model
types. Apollo iOS for GraphQL with Firebase bearer auth.

### 9.1 Navigation

A `TabView` with three content tabs plus a detached Scan tab, using the same `scanTabRole`
OS-version shim as Vinarium's `ContentView.swift`.

| Tab | Content |
|---|---|
| Home | Books currently being read, and reading statistics |
| Library | Every book, grouped into series sections, filterable by status |
| Series | The sagas followed, each in progress or complete |
| Scan | The camera, full screen |

### 9.2 Feature structure

`ios/Shiori/Features/{Feature}/` with the coordinator `{Feature}View.swift` at the root and
`components/{pages,organisms,molecules}` below; cross-feature atoms in
`ios/Shiori/Shared/Components/`. The feature-root `*View` owns the view model, navigation,
sheets and domain-to-primitive mapping; the `*Page` is pure and previewable.

Features: `Home`, `Library`, `Series`, `Scan`, `Book`, `Search`, `Auth`, `Onboarding`,
`Settings`, `Subscription`, `Admin`.

### 9.3 Localisation

French and English at launch, through a `Localizable.xcstrings` String Catalog. The full
localisation machinery is built from the start — the Gemini prompt is parameterised by
language, the scan cache is keyed by language, the changelog is one file per language — so
adding a market later is filling in strings, not rebuilding.

## 10. Testing

Three suffixes, three CI workflows, as in Vinarium:

- `*.unit.test.ts` — primitives, series grouping rules, complete/in-progress state, volume
  kind ordering
- `*.int.test.ts` — commands and queries against the fake Firestore, with read-budget
  assertions
- `*.feat.test.ts` — GraphQL against the built schema

Four end-to-end journeys under `scripts/e2e.sh` (Firebase emulators, Nitro, simulator), which
gate the release:

1. Scan a book and save it
2. Rate a finished book with stars and a note
3. Add a volume from the series screen
4. Exhaust the quota and reach the paywall

The scan is stubbed under `import.meta.dev`, tree-shaken out of any built bundle: a release
gate cannot depend on a paid, non-deterministic model.

## 11. Delivery phases

The spec covers batches 1 and 2 in full. The implementation plan delivers them in this order,
each phase leaving something that works.

| Phase | Content | State at the end |
|---|---|---|
| 0 — Foundation | Repo, Terraform, Firebase, CI, Nitro and GraphQL skeleton, Sign in with Apple, iOS app that connects | The app launches and authenticates |
| 1 — Library | `book` domain, manual add, statuses, rating, note, `hidden`, list and detail screens | **A usable app with no AI at all** |
| 2 — Scan | Gemini vision and enrichment, cache, cover storage, review screen, quota | Scanning replaces typing |
| 3 — Series | Catalogue, catalogue call, library grouping, series screen, recommendations, related works | Batch 2 complete |
| 4 — Freemium | `entitlement`, StoreKit, paywall, welcome credits, admin metrics | Monetisation live |
| 5 — Release | fr/en localisation, screenshots, changelog, App Store submission | Shipped |

Phase 1 deliberately precedes the scan: it produces an app that is genuinely usable while the
rest is built, and it validates the data model before a paid pipeline is wired to it.

## 12. Operations outside this repository

Two steps cannot be automated from here because they commit real money and a real Apple
account:

- Creating the Shiori app record in App Store Connect, its API key, and its subscription
  products

The Terraform and the workflows are written so both are a single command once the accounts
exist.
