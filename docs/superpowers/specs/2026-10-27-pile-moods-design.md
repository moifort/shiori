# Pile moods — design

## Problem

The "Pile à lire" shelf lists every book on the pile, last shelved first. It answers "where is
the book I just added", not "what do I read next". With forty books on the pile, the reader
scrolls the whole list and picks nothing: a long list of equal options, with no stated
preference, is the case in which choice overload shows up (Chernev, Böckenholt & Goodman, 2015).

Sorting the pile into genre sections was weighed and rejected: it reorders the same forty books
without narrowing them, it takes the "just added" order away, and sections cut from a paged list
reshuffle as each page arrives.

## Decision

Four tiles over the pile, under "J'ai envie de…". Each one names an intent and narrows the
pile to the books that match it:

| Tile | Keeps | Order | Under the label |
|---|---|---|---|
| **La suite** | The next volume of each saga the reader is in | Saga last touched first | "2 séries en cours" |
| **Un livre court** | Novels of at most 250 pages, recordings of at most 6 hours | Shortest first | "Moins de 250 p." |
| **Changer de genre** | Books outside the genre the reader keeps finishing | Last shelved first | "Après 3 fantasy" |
| **Le plus ancien** | The whole pile | Longest on the pile first | "Depuis 2024" |

No tile is selected when the shelf opens: the list stays as it is today. A tap selects a tile and
narrows the list, a tap on the selected tile clears it. One tile at a time.

Every rule is computed from the reader's library. **No paid API is called.**

## Goals

- Pick a book in two taps when the reader does not know what they want.
- Keep the pile's current order and use untouched when no tile is selected.
- Say why each tile holds what it holds, on the tile and on each row.

## Non-goals

- A model-chosen pick ("Choisis pour moi"). Découvrir already spends a Claude call a month; a
  second is not justified until these rules are shown not to be enough.
- Combining tiles ("court **et** la suite").
- Genre pills. A reader who wants science fiction opens the genre page, which exists.
- Tiles on any shelf other than the pile.

## Anti-goals

- Never call the catalogue (`series/…`) to decide a tile: series membership is on the book.
- Never change a book's status or order from a tile.

## The rules

All four are pure functions in `server/domain/library/business-rules.ts`, over the pile (books
`to-read`, in the shelf's format when a format pill is set) and the rest of the library.

### `next-in-series` — La suite

A pile book belongs here when:

1. it carries `series` with a `volume`, and its `series.kind` is `main`;
2. the reader holds another book of the same `series.saga`, `read` or `reading`, with a lower
   volume;
3. no pile book of that saga has a lower volume — only the next one is kept, not every one left.

Order: the saga whose last `finishedAt` (or `startedAt` for a book being read) is the most recent
first. Row line: "Tome 2 fini il y a 3 semaines".

The saga is matched on `saga`, not `id`: a reader who read volume 1 in French and holds volume 2
in English is still in the saga.

### `short` — Un livre court

- `book` format: `pageCount` ≤ 250.
- `audiobook`: `durationMinutes` ≤ 360.
- `bande-dessinee`, `comic`, `manga`: never. Every album is short; kept, they would fill the tile
  and say nothing.
- A book with no length is never kept.

Order: shortest first. Row line: "184 p." / "4 h 20".

The thresholds are a product choice, not a finding. They are constants, to be moved once readers
use it.

### `change-genre` — Changer de genre

The reader's **streak genre** is the genre of at least 2 of their last 3 finished books
(`read`, by `finishedAt`). The tile keeps the pile books that have a genre and whose genre is
not the streak genre.

No streak genre (the last three are all different, or fewer than 2 books finished): the tile is
not shown. Order: last shelved first. Under the label: "Après 3 fantasy" — the number counts how
many of the last three share the genre.

### `oldest` — Le plus ancien

The whole pile, longest on the pile first: `statusChangedAt`, falling back to `addedAt`, oldest
first. Under the label: the year of the oldest book. Row line: "Dans ta pile depuis 2 ans".

This tile keeps everything; it is a sort. It earns its place because the oldest books are the
ones a last-shelved-first list never shows.

### When tiles show

- A tile with nothing to keep is not shown.
- The whole block shows only when the pile holds at least 5 books **and** at least 2 tiles have
  something to show. Under that, the list is short enough to read.
- The block follows the format pill: on "Livres audio", the tiles count audiobooks only.

## Cost

No paid API. The pile shelf already reads the library once through `BookQuery.all` for the rails
and for the genre filter; the tiles and a tile's list are computed from that same scan. Reads per
opening: one document read per book of the library, as the genre filter already costs.

## Server

### `pileMoods(format: BookFormat): [PileMood!]!`

```graphql
type PileMood {
  mood: PileMoodKind!          # NEXT_IN_SERIES | SHORT | CHANGE_GENRE | OLDEST
  count: Int!
  seriesCount: Int             # NEXT_IN_SERIES: sagas in progress
  streakGenre: Genre           # CHANGE_GENRE
  streakLength: Int            # CHANGE_GENRE: 2 or 3
  since: Date                  # OLDEST: when the oldest book joined the pile
}
```

Only the tiles to draw, in the table's order; an empty list when the block should not show. The
labels are written by the app, not the server: the server gives facts, the app the French.

### `libraryPage(mood: PileMoodKind)`

A new optional argument on the existing query, beside `genre`. Only meaningful with
`status: TO_READ`; with any other status it is a bad user input. Like `genre`, it is ordered in
memory from the library scan, with the same cursor.

Each book row of a mood page carries why it is there, for the row's third line: a
`moodReason` field on the page entry, holding the previous volume's `finishedAt` (La suite), the
length (court) or the date it joined the pile (ancien). Nothing for Changer de genre: the genre
already shows.

New optional argument and new type: no migration, no deprecation.

### Tests

- `business-rules.unit.test.ts`: each rule, with its edges — a saga read in another language,
  two pile volumes of one saga (only the lower kept), a novel with no page count, a manga of
  40 pages (never short), a streak of 2 out of 3, no streak, a pile of 4 (no block).
- `use-case.int.test.ts`: `pileMoods` and a mood page read the library once — `fake.queryReads`
  is 1 and `fake.docReads` the library's size.
- `queries.feat.test.ts`: the GraphQL shape, `mood` refused on a status other than `TO_READ`.

## iOS

- `BookShelfPage` on the `toRead` shelf draws the tiles under the title, in a 2-column grid,
  above the format pills' list. A pure view takes `[PileMood]` and the selection; the screen's
  view model loads `pileMoods` with the shelf and reloads it when the format pill changes.
- Selecting a tile sets `query.mood` and reloads, as `select(format:)` does. The heading over
  the list reads the tile's count: "6 livres de moins de 250 pages".
- Rows of a mood page draw `moodReason` as their third line, in place of genre and date.
- Strings in French in the Swift code, English in `Localizable.xcstrings`; run
  `bun scripts/check-strings.ts` after the build.
- Snapshots: no tile selected, each tile selected, block hidden (pile of 4).

## Open questions

- **Default selection.** None, so the pile reads as today. The alternative is "La suite"
  preselected when it exists — the likeliest next book. Decide before building.
- **Thresholds.** 250 pages and 6 hours are guesses. Revisit after a month of use.
