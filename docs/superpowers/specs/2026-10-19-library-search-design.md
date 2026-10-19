# Library search — design

## Problem

A reader talking about a book remembers a fragment of it — "Dungeon Crawler something" — and
not the author, nor which tome they are on. The Library tab has no way to find it: the list is
paged from the server (`libraryPage`, newest first), so scrolling is the only search, and a
filter on the rows already drawn would miss every book that has not scrolled in yet.

## Decision

A magnifying glass at the top left of the Home and Library tabs opens one search screen. It finds
the reader's own books by title, author or series as they type, forgives a typo ("card" finds
"Carl"), and opens a book's page or a saga's page from the result.

The search runs **on the phone**, over a light index of the whole library fetched once and kept on
disk. Firestore is not asked per keystroke.

### Why not a keyword array in Firestore, as Vinarium does

Vinarium writes a `searchIndex` array of canonical words on each wine and asks Firestore for the
most selective one with `array-contains-any`. It was weighed and rejected here:

- `array-contains` tests equality: a word only matches once typed whole, and a typo never
  matches. Search as you type would need every prefix indexed, which Vinarium itself declined.
- Every write path of a book would have to rebuild the array — scan, `addBook`, Kindle import and
  sync, Audible, the edit form, saga rename and merge (the saga name is denormalized on each book).
  One forgotten path makes a book silently unfindable.
- It needs a backfill migration and a composite index, to save reads that cost nearly nothing at
  a reader's scale.

What is taken from Vinarium is the normalization (`normalizedForSearch`): lowercase, accents and
separators stripped, on both sides.

If one day the search has to reach a set too large to load — every friend's library — the keyword
array can be added then, on the same normalization.

## Goals

- Find a book of one's own library from a fragment of its title, an author or its saga's name,
  with results updating at every keystroke.
- Tolerate one wrong letter in a word of four letters or more.
- Narrow the results, or list without typing, with the filters Favoris, En cours, À lire, Lus.
- Open a book's page, or a saga's page, from a result.

## Non-goals

- Searching books the reader does not hold: no Découvrir, no catalogue, no friends' libraries.
  An empty result says so and offers nothing else.
- The Abandonnés filter: noise in a search, the Library tab's own filter keeps it.
- Searching notes, subgenres, ISBN, publisher.
- Spotlight indexing (a possible follow-up, not this scope).

## Anti-goals

- A search that misses a book the reader holds because it has not been paged in.
- A loader on every opening: it shows only when there is no index on disk yet.
- Any per-keystroke network request.

## Cost

No paid API. Opening the search reads the reader's library once from Firestore when the index on
disk is stale: N document reads for N books. A 5,000-book library opened three times a day is
15,000 reads a day, about €0.27 a month at €0.06 per 100,000, and within the 50,000 free daily
reads at any realistic scale. A 300-book library costs nothing measurable.

## Server

Two additive queries in the book domain. No field is removed, so no deprecation.

### `librarySearchIndex: [Book!]!`

Every book of the reader. `BookQuery.searchIndex(userId)` reads `repository.findAllByUser` — one
query, N document reads — and returns the books as they are, **without signing any cover**:
signing 5,000 URLs would cost more than the whole search, and a signed URL lives an hour while the
index lives on disk for days. `coverUrl` is therefore always null on this query, which its
description says; `BookQuery.shared` already hands unsigned books the same way.

It returns the existing `Book` type rather than a dedicated one: a second type would restate a
dozen field resolvers (`shelvedAt`, `seriesRating`, `listeningProgress`…) for no gain. The app asks
only for what a row draws: `id`, `title`, `authors`, `format`, `media`, `language`, `status`,
`listeningProgress`, `rating`, `seriesRating`, `favorite`, `shelvedAt`,
`series { id name volume kind }`. `seriesRating` scans the saga opinions once per request.

About 200 bytes a book in JSON: 1 MB for 5,000 books, a fifth of that compressed.

### `bookCovers(ids: [BookId!]!): [BookCover!]!`

`BookCover { id: BookId!, coverUrl: String }` for the reader's own books among `ids`, through the
same `withCover` the library uses (and its signature cache). At most 50 ids per call; more is a
`badUserInput`. Ids the reader does not own are left out, not an error. Reads the books by id —
one document read each.

### Tests

- `*.int.test.ts`: the index costs one query read and N document reads (`fake.queryReads`,
  `fake.docReads`), returns no cover, and carries the borrowed saga stars; `bookCovers` reads only
  the ids asked, skips another reader's book.
- `*.feat.test.ts`: both queries through the built schema, including the 50-id limit.
- `bun run schema:check` passes (additive only).

## iOS

### Entry points

`ToolbarItem(placement: .topBarLeading)` with a `magnifyingglass` button on the Home tab
(`HomeScreen`) and the Library tab (`LibraryPage`); both places are empty today. It presents
`LibrarySearchScreen` as a sheet at full height, with its own `NavigationStack` and a close button.

### The index

`LibrarySearchIndex` (shared, owned by the app so both tabs use one copy):

- Kept on disk with `SnapshotCache("library-search", version: 1)`.
- **Opening the search** with an index on disk: results come from it at once; it is refreshed in
  the background when it is older than one hour or marked stale. Without one: a loader,
  "Préparation de vos livres…", for the one or two seconds the request takes.
- **Marked stale** on every `shioriDataDidChange` notice, with or without a `DataChange`. The next
  opening refreshes it silently. Patching single entries was weighed and rejected: a deleted book
  or a renamed saga leaves no trace to patch from, and a full reload is cheap and always right.
- A failed refresh keeps the index on disk and says nothing; a failed first load shows the error
  with a retry button.
- Each entry's searchable text is normalized once, when the index is loaded, not per keystroke.

### Matching

Pure functions in their own file, unit-tested:

- **Normalization**: lowercase, diacritics removed, `-`, `'`, `’`, `:` and other punctuation turned
  to spaces, spaces collapsed. "L'Assassin royal" → "l assassin royal".
- **A book's words**: those of its title, its authors and its saga's name.
- **A query matches a book** when every word of the query matches one of the book's words:
  - the book's word starts with the query word ("dung" → "dungeon"); or
  - the query word has four letters or more and is one edit (insertion, deletion, substitution)
    away from the book's word or from its prefix of the same length ("card" → "carl");
  - a query word that is a number also matches the book's tome number ("carl 3").
- **Ranking**: exact prefix matches before matches that needed an edit; then a match in the title
  before one only in the author or saga; then saga order (saga name, tome); then title.
- Budget: 5,000 books under 10 ms per keystroke on a recent iPhone. The matcher's unit tests
  include a 5,000-entry case with a loose ceiling (one second), so a slow CI simulator never flakes
  while a quadratic slip still fails.

### The screen

As drawn in the mockup of 2026-10-19 (states 1 to 4):

- **Search field** (`.searchable`, always presented, placeholder "Titre, auteur, série").
- **Filters**: chips under the field — Favoris, En cours, À lire, Lus. Favoris is a toggle and
  combines with a status; the three statuses are mutually exclusive (tapping the active one clears
  it). They apply to the books and the sagas alike.
- **Empty field, no filter**: up to five recent searches, then nothing else.
- **Empty field, a filter on**: the recent searches, then every book the filter keeps, newest on
  the shelf first (`shelvedAt`).
- **Results**:
  - **Série** first: each saga whose name, or whose authors, match the whole query, at most three,
    with the reader's held volume count ("5 tomes"). It opens `SeriesScreen`, pushed in the search's
    stack.
  - **Livres** next: the matching books, ranked as above, drawn with the existing `BookRow`, its
    status tag included. An index entry maps to the app's `Book` with no cover, and the fields
    the index does not ask for at their empty value. The matched part of the title is highlighted. A tap opens `BookScreen` as
    a sheet, as the Library does.
- **No result**: "Aucun livre ne correspond". When a filter hides books that match, the screen says
  how many ("1 livre hors favoris correspond.") and offers "Retirer le filtre".
- **Covers**: rows draw their placeholder, then `bookCovers` is asked for the visible rows, at most
  50, 300 ms after the typing pauses. Covers already fetched are kept in memory for the screen's
  lifetime.
- **Recent searches**: a query is remembered when a result is opened from it; five kept, newest
  first, in `UserDefaults`; tapping one fills the field.

### Structure

Following [docs/ios-guide.md](../../ios-guide.md): a pure `LibrarySearchPage` fed by values, a
connected `LibrarySearchScreen` owning a `LibrarySearchViewModel`, a `LibrarySearchClient` with a
live and a preview implementation, `#Preview`s for the four states and a static preview fixture,
including the Dungeon Crawler Carl case.

### Strings

French in Swift, English in `Localizable.xcstrings`, checked with `scripts/check-strings.ts
--write` after the build.

### Tests

- Matcher: normalization, prefix, one-edit tolerance and its four-letter floor, tome number,
  ranking, the 5,000-entry budget.
- View model: loader only without an index on disk, background refresh when stale, filters
  combining, saga section limited to three, the no-result count under a filter, covers asked for at
  most 50 ids.

## Left to the builder

- The exact layout of the saga row (stacked covers or a single cover).
- Whether the highlight also marks the matched author.
- How the Home and Library tabs share the one index instance (environment object or app-level
  owner).
