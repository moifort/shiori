# Découvrir by series Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Découvrir shows what is coming next in the sagas the reader follows, in any language,
through the Library's "Livres | Séries" capsule, rows and screens; the weekly watch writes
release dates into the shared saga catalogue.

**Architecture:** The catalogue's `Volume` gains per-language `releases`, `titles`, `covers`.
The series rules judge "out" per edition language and count an exact-day announcement in the
spine. The discover watch becomes a release watch per work edition (`release-watches`), merged
into the catalogue after each search. `Discover` serves `upcoming` and `maybe` as `Release`s;
a series release carries the Series tab's `FollowedSeries` row. A shared, unmetered
`bookPreview` builds a book's record on tap.

**Tech Stack:** Nitro + Pothos GraphQL + Firestore (fake in tests), Bun tests, SwiftUI + Apollo iOS.

**Spec:** `docs/superpowers/specs/2026-09-24-discover-by-series-design.md`

## Global Constraints

- English for code, comments, commits; French only in `Localizable.xcstrings` and `CHANGELOG.fr.md`.
- Flat collections, no subcollection; a shared document holds no `userId`.
- Never `console.*`; `createLogger(tag)`, constant messages, context apart.
- Biome: spaces, single quotes, no semicolons, width 100.
- Verify: `bunx nitro prepare && bunx tsc --noEmit`, `bun test` per suffix
  (`bun test .unit.`, `bun test .int.`, `bun test .feat.`), `bunx biome check`.
- `bun run generate:graphql` then `cd ios && apollo-ios-cli generate` after schema changes.
- Never push.

---

### Task 1: Release dates in the catalogue, judged per language

**Files:**
- Modify: `server/domain/series/types.ts` (Volume), `server/domain/series/primitives.ts`
  (move `ReleaseDate` constructor here), `server/domain/discover/primitives.ts` +
  `types.ts` (re-export), `server/domain/series/business-rules.ts`,
  `server/domain/series/use-case.ts`, `server/domain/analytics/business-rules.ts` + callers
- Test: `server/domain/series/business-rules.unit.test.ts`, analytics unit tests

**Interfaces — Produces:**
- `Volume.releases?: Partial<Record<BookLanguage, ReleaseDate>>`, `Volume.titles?`, `Volume.covers?: Partial<Record<BookLanguage, CoverUrl>>`
- `releaseOf(volume, language?): ReleaseDate | undefined` — the edition's date; without a language, the earliest exact day of any
- `isForthcoming(volume, today: string, language?): boolean` — the edition's date decides when present (a day after today, or a month/year not over); else `publishedIn > year(today)`
- `measuredSpineOf(series, today, language?)` replaces `publishedSpineOf`: numbered main volumes out, or announced to the day
- `stateOf(series, read, today, language?)`, `progressOf(series, read, today, language?)`, `followedStateOf(statuses, catalogue, read, today, unfollowed, language?)`
- `withReleases(series, language, found: FoundVolume[]): Series` where `FoundVolume = { volume: VolumeNumber; title: BookTitle; date?: ReleaseDate; coverUrl?: CoverUrl }` — sets the three maps, appends a missing numbered main volume, never removes
- `SeriesCommand.recordReleases(seriesId, language, found)` — reads, merges, saves only when changed; `SeriesCommand.catalogue` carries previous `releases/titles/covers` onto matching volumes

Tests: exact-day announcement flips complete → in-progress; month-only stays complete; a FR date does not make the EN row forthcoming; merge adds/corrects/never removes; recatalogue keeps releases.

### Task 2: Series GraphQL exposes releases

**Files:** `server/domain/series/infrastructure/graphql/types.ts`, `queries.ts` (pass language into state/progress), feat test.

`Volume.releases: [VolumeRelease!]!` with `language: BookLanguage!`, `date: String!`,
`title: BookTitle`, `coverUrl: CoverUrl`.

### Task 3: The release watch

**Files:** `server/domain/discover/{types,business-rules,prompts,schemas,parsing,use-case,command,query}.ts`, `infrastructure/repository.ts`, unit + int tests.

**Interfaces — Produces:**
- `WatchedWork = { key; kind: 'series' | 'book'; seriesId?; title; author?; language: BookLanguage /* searched */; readIn: BookLanguage; volumesRead; cover; lastActivity }`, key `series--{id}--{lang}` / `book--{shelfKey}--{lang}`
- `watchedWorksOf(followed: FollowedSeries[], books: Book[], appLanguage)` — sagas `in-progress`/`complete` with a language: one work in their language, one in the app's when it differs; standalone books read in another language: one in the app's
- `ReleaseWatch` in `release-watches` (was `TranslationWatch`), editions carry `coverUrl` resolved by `publishedCoverOf(isbn13)`
- after saving a series watch: `SeriesCommand.recordReleases(seriesId, language, bookEditions)`
- `releasesOf(...) → { upcoming: UnsignedRelease[]; maybe: UnsignedRelease[] }`: upcoming = a dated edition to come, soonest first; maybe = a translation out in the app's language (readIn ≠ language = app language), nothing to come
- `DatedEdition` gains `language` and `readIn`; `alertOf` says "Nouveau tome" for a same-language volume, "Enfin traduit" for a translation

### Task 4: Discover GraphQL

**Files:** `server/domain/discover/infrastructure/graphql/{types,queries,mutations}.ts`, feat test, `shared/schema.graphql`.

`Discover { preparedAt, canRefresh, upcoming: [Release!]!, maybe: [Release!]! }`,
`Release { key, kind, language, title, author, seriesId, series: FollowedSeries, editions: [ReleaseEdition!]!, nextDate }`,
`ReleaseEdition { title, volume, format, date, isbn13, coverUrl, audibleUrl }`. `dismissRelease(key)` replaces `dismissTranslation`.
`FollowedSeriesType` is exported from series queries for reuse.

### Task 5: Book preview

**Files:** `server/domain/discover/` (preview business rule + repository `book-previews`), GraphQL query `bookPreview(title, author, language, isbn13, seriesId, volume, releaseDate)` → `BookPreview` (ScanResult fields + `releaseDate`). Unmetered, cached shared, rebuilt once a cached announced book is out. Int + feat tests.

### Task 6: Migration 007

`server/system/migration/migrations/007-discover-is-releases.ts`: delete `translation-watches`; rewrite feed `dismissed` (`x` → `x--{feed.language}`) and `notified` (`{work}--{format}--{v}` → `{work}--{lang}--{format}--{v}`); clear `dated`. Int test.

### Task 7: iOS — catalogue releases and the shared series row

`Book.swift` Volume gains `releases`; `isForthcoming(today:language:)`, `countsInSpine`; `SeriesStripItem.missing` gains `date` and `coverUrl`; `SeriesRow` extracted from `SeriesListView` into `Features/Series/SeriesRow.swift`, drawing the date under an announced cover; `SeriesView` shows "Sort le 8 octobre 2026" and measures its ring per language.

### Task 8: iOS — Découvrir with shelves

`DiscoverView` rebuilt: `LibraryShelfPicker` over `discover-shelf`, format filter kept, sections "À venir" / "Vous intéresse peut-être"; Séries shelf draws `SeriesRow` and pushes `SeriesView(seriesId:language:)`; Livres shelf draws book rows with `ReleaseDateBadge` and opens `BookPreviewView` (`BookPage` in preview mode: release date, "Ajouter à lire", "Pas intéressé"). `TranslationView` removed. Strings in `Localizable.xcstrings`.

### Task 9: Changelog, roadmap, verification

`CHANGELOG.md` / `CHANGELOG.fr.md` under `## Unreleased`, typecheck, three test suffixes, biome, xcodebuild, simulator screenshots for approval.
