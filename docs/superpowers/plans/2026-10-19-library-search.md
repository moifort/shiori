# Library search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A search screen, opened from the Home and Library tabs, that finds the reader's own books by title, author or saga as they type.

**Architecture:** The server hands the whole library once, without covers (`librarySearchIndex`), and signs covers for the visible rows only (`bookCovers`). The app keeps the index on disk and matches locally with a pure, typo-tolerant matcher.

**Tech Stack:** Nitro + Pothos + Firestore (bun tests against the fake); SwiftUI + Apollo iOS (Swift Testing).

**Spec:** [docs/superpowers/specs/2026-10-19-library-search-design.md](../specs/2026-10-19-library-search-design.md)

## Global Constraints

- Additive schema only; `bun run schema:check` passes.
- No paid API; the index read is one query, N document reads.
- `bookCovers` takes at most 50 ids; more is `badUserInput`.
- Filters: Favoris (toggle) + one of En cours, À lire, Lus. No Abandonnés, no Découvrir.
- One-edit tolerance only for query words of four letters or more.
- French strings in Swift, English in `Localizable.xcstrings`.

## Review Focus

- A query of only spaces or punctuation: treated as empty, never "no result".
- Apostrophes and accents ("l'assassin", "Ève"): match the normalized words both ways.
- A book without authors or without a saga: still indexed by its title.
- A filter on with an empty field: lists what the filter keeps, newest first.
- Stale index after an edit: refreshed silently on the next opening.

---

### Task 1: Server queries

**Files:** `server/domain/book/infrastructure/repository.ts` (`findByIds`), `server/domain/book/query.ts` (`searchIndex`, `covers`), `server/domain/book/infrastructure/graphql/{types,queries}.ts`, `server/domain/book/command.int.test.ts`, `server/domain/book/infrastructure/graphql/queries.feat.test.ts`, `shared/schema.graphql`.

**Interfaces:** `BookQuery.searchIndex(userId): Promise<Book[]>`; `BookQuery.covers(userId, ids: BookId[]): Promise<{ id: BookId; coverUrl?: CoverUrl }[]>`; GraphQL `librarySearchIndex: [Book!]!` (covers never signed, `coverUrl` null), `bookCovers(ids: [BookId!]!): [BookCover!]!`.

- [ ] Int tests: index is 1 query read + N docs, no `coverUrl`; covers read only the ids asked and skip another reader's book.
- [ ] Feat tests: both queries through the schema; 51 ids → `BAD_USER_INPUT`.
- [ ] Implement, regenerate the schema, run typecheck, tests, biome, schema:check. Commit.

### Task 2: iOS matcher

**Files:** `ios/Shiori/Features/Search/LibrarySearchMatching.swift`, `ios/ShioriTests/Search/LibrarySearchMatchingTests.swift`.

**Interfaces:** `SearchText.normalized(_:) -> String`; `SearchEntry` (book + normalized words); `LibrarySearchMatcher.results(for query: String, in: [SearchEntry], filter: SearchFilter) -> SearchResults` with `series: [SeriesHit]` (≤ 3) and `books: [Book]`.

- [ ] Tests: normalization, prefix, one-edit with four-letter floor, tome number, ranking, saga section ≤ 3, 5,000 entries under 100 ms.
- [ ] Implement. Commit with Task 3.

### Task 3: iOS index, client, view model

**Files:** `ios/Shiori/Features/Search/GraphQL/Search.graphql`, `LibrarySearchClient.swift`, `LibrarySearchIndex.swift`, `LibrarySearchViewModel.swift`, `ios/ShioriTests/Search/LibrarySearchViewModelTests.swift`.

- [ ] Tests: loader only without an index on disk; stale index refreshed in the background; filters combine; hidden-by-filter count; covers asked for ≤ 50 ids.
- [ ] Implement; `apollo-ios-cli generate`.

### Task 4: iOS screen and entry points

**Files:** `ios/Shiori/Features/Search/components/pages/LibrarySearchPage.swift`, `LibrarySearchScreen.swift`, `HomeScreen.swift`, `LibraryPage.swift`/`LibraryScreen.swift`, `Localizable.xcstrings`.

- [ ] Pure page with `#Preview`s for the four states; screen wiring `BookScreen` sheet and `SeriesScreen` push; loupe at `.topBarLeading` on both tabs.
- [ ] Build, `check-strings.ts --write`, fill English, unit tests, screenshots of the four states. Commit.
