# One series id per edition — design

## Why

A book names its saga by a key shared across languages (`dune--frank-herbert`) and records its
language apart. Every client that opens a saga page has to carry the pair, and the one that
forgot — the home "Mes séries" card, fed by `seriesProgressOf` — opened a page mixing the French
and English editions: one catalogue, the other edition's volumes. The pair is a convention the app
was trusted to rebuild; the fix is to stop asking it to.

Each language edition of a saga becomes a series of its own, with its own identifier, **written in
the data** and returned by the server. A client never builds it: it passes back the id it was given.

## Goals

- The public `SeriesId` names one edition: `{sagaKey}~{language}` — exactly the catalogue document
  id `catalogueKeyOf` already writes (`series/dune--frank-herbert~fr`).
- Every book stores its edition id in `series.id`. A forward-only migration rewrites every existing
  book.
- Every GraphQL field that tells which saga a book, a row, a card or a hit belongs to answers the
  edition id. Every argument taking a `SeriesId` accepts it alone, without a `language`.
- Every entry point of the app opens the edition it shows. `SeriesScreen` / `SeriesDestination`
  take the id alone.
- The saga hero shows the language tag of a foreign edition, as the book hero does.

## Non-goals

- The reader's opinion of the work does not split by edition: rating and heart stay per saga
  (see below).
- No change to how a catalogue is built, refreshed or watched; no new model call. **Gemini cost:
  none** — no catalogue, release watch or award document is re-keyed, so nothing is asked again.
- No removal from the schema in this change: what installed builds use is deprecated, never
  dropped (`docs/api-evolution.md`).

## Anti-goals

- The app splitting or concatenating an id, or deciding a language to pair with it.
- An installed build losing a saga page, a rating, a follow toggle or a deletion because the ids
  changed under it.
- A migration that leaves a book pointing at a catalogue that does not exist.

## Vocabulary and the two keys

| | Meaning | Example | Brand |
|---|---|---|---|
| **Saga key** | the work, whatever the language | `dune--frank-herbert` (`…--audio` for the saga heard) | `SagaKey` (new, server-internal) |
| **Series id** | one edition of it | `dune--frank-herbert~fr` | `SeriesId` (existing brand and scalar) |

`seriesKeyOf(name, author, format)` returns a `SagaKey`. A new primitive
`seriesIdOf(saga, language)` builds a `SeriesId`; it is called **only when something is written**
— a book added, edited or imported, a catalogue stored, a saga proposed on an author's page — never
to read. `isAudioSeries`, `seriesIdFor` (format moves) and `keyWithAuthorReversed` work on the saga
key.

Every book and every catalogue carries a language since migrations 015 and 016, so every series id
carries a `~`. A bare key reaching the API is therefore always an installed build speaking the old
language, never an edition without one.

## Data

### Books — `books/{bookId}`

`SeriesMembership` gains the saga key beside the edition id:

```ts
type SeriesMembership = {
  id: SeriesId     // the edition: `dune--frank-herbert~fr`
  saga: SagaKey    // the work: `dune--frank-herbert`
  name: SeriesName
  volume?: VolumeNumber
  kind: VolumeKind
}
```

`saga` is denormalized on purpose, like the name: the library groups rows by `id`, reads the
opinion by `saga`, and neither parses a string. Whenever a book's language or format changes,
`BookCommand` rewrites both.

### Catalogues — `series/{seriesId}`

The document id does not change. Its fields do: `id` holds the series id (it held the saga key) and
a new `saga` field holds the saga key. **This is where the edition→saga link lives**: a stored
field on the edition's own document, plus the copy on each book. `language` stays.

`series-misses/{seriesId}` gets the same two fields.

### Opinions — `series-opinions/{userId}--{sagaKey}`: unchanged

The rating, the heart and the reader's volume count stay per saga — a reader who owns Dune twice
does not think twice about it. The stored field keeps its name `seriesId` and holds the saga key
(typed `SagaKey`); renaming it would cost a migration for nothing.

**Following stays where it is.** Setting one edition aside is already stored per edition, as
`unfollowedLanguages` on the saga's opinion, and the whole-saga flag `unfollowed` is what installed
builds write. Moving following onto a per-edition document would migrate every opinion to say the
same thing. The change is in the API: `setSeriesFollowed` given a series id moves that edition
only.

### Left keyed on the saga key, on purpose

- `saga-watches/{sagaKey}--{language}` — the release watch's shared, paid result. Re-keying it
  would ask Gemini again for every watch. Internally it is a `SagaKey` plus a language.
- `authors`, award and Découvrir documents that name sagas by key — read through the books.
- `suggestion-queues` references (`seriesId?`) — a stored bare key opens through the
  compatibility path below until the queue is refilled.

### Analytics — `analytics/{userId}`

The stored dashboard view holds `seriesInProgress[].id`. The migration marks every view stale, so
the next home opening rebuilds it with series ids — reads only.

## The migration — `027-books-name-their-edition`

Forward-only, raw documents (no domain types), batches of 400, idempotent:

1. `books`: for each book with `series`, where `series.id` holds no `~`:
   `saga = series.id`, `id = "${series.id}~${language ?? 'fr'}"`. A book whose `id` already holds a
   `~` is left alone.
2. `series` and `series-misses`: for each document whose id holds a `~`, set `id` to the document
   id and `saga` to the part before the `~`. The bare documents left by migration 013 (no book
   points at them since 015/016) get `saga = id` and are otherwise untouched.
3. `analytics`: `stale: true` on every view.

The Deploy workflow runs migrations after Terraform has put the new revision live, so for the
length of that step (well under a minute) the new code reads books not yet migrated: a saga page
or the Series tab can show the wrong edition grouping until the step ends. Accepted rather than
carried by a read-time fallback that would outlive it; no write during the window is lost, since a
book written then is written in the new form and the migration skips it.

Its test covers a book per case (French, English, audiobook, no language, already migrated), a
catalogue, a miss, and a view, and runs twice to prove idempotence.

## The API

### What answers a series id

These start answering the edition id, keeping their names and types: `Book.series…id`,
`FollowedSeries.id`, `Series.id`, `SeriesProgress.id` (home card), the Découvrir rows, the author
page sagas, the search hits, a friend's sagas, `ScanResult` series. Their descriptions are rewritten
("the edition: what to open").

`SeriesOpinion.seriesId` keeps answering the saga key, described as such.

### What takes a series id

Every argument typed `SeriesId` — `series`, `mySeriesVolumes`, `myFollowedSeries`, `deleteSeries`,
`mergeSeries` (both ids), `refreshSeries`, `setSeriesFollowed`, `rateSeries`, `removeSeriesRating`,
`setSeriesFavorite`, `declareSeriesVolumeCount`, `seriesOpinion`, `addAudibleSeriesVolume`,
`addBook`/`updateBook` series inputs — goes through one boundary function:

- **a series id** (`~`): that edition. A `language` argument beside it is ignored.
- **a bare key** (installed build): the behaviour of today, unchanged — the edition from the
  `language` argument, else every edition for `deleteSeries` / `mergeSeries` / `mySeriesVolumes`,
  the whole saga for `setSeriesFollowed`, the held edition for `series`.

The opinion mutations take the saga from the edition. For `addBook` / `updateBook`, the id the
client sent only names the saga: the stored id is built from the book's own language and format, as
it is today.

Every `language` argument that sits beside a series id is **deprecated** in the same commit
("the series id names the edition"), never removed. `FollowedSeries.language` and `Series.language`
stay — the app shows them.

This boundary function is the one place a series id is split: it must recognise an old bare key
anyway, and splitting on the `~` no slug can produce is exact. Inside the domain, the saga is read
from the stored `saga` fields.

### What installed builds see

They pass back what they are given, with the `language` they always sent; both now resolve to the
same edition. One visible regression: the build on sale tests `seriesId.hasSuffix("--audio")` for
the "heard" mark on the saga page, which an edition id (`…--audio~en`) no longer ends with. It goes
until they update; the new build reads `Series.audio`.

## iOS

- `SeriesDestination(seriesId:proposal:)` — identity is the id. `SeriesScreen(seriesId:proposal:)`
  drops `language`; its queries stop sending it. `addAudibleSeriesVolume` takes the language from
  the catalogue the page loaded.
- Every entry point passes the id it was given: Series tab, book page, home "Mes séries" card,
  Découvrir (rows and announced volume), author page (held sagas and proposed ones), search,
  friend's book and friend's sagas.
- The Series tab keys rows on the id alone; `refreshRows`, `holds` and `lacksCatalogue` likewise.
- The "heard" mark reads `series.audio`, not the id's suffix.
- `SeriesHero` shows the language tag when the edition is not in the reader's own language, with the
  component the book hero uses.
- `.graphql` operations drop the deprecated `language` arguments; codegen regenerated.

## Done

- This spec approved.
- The migration and its test; server unit, integration and feature tests updated (suffixes run
  apart); `bunx nitro prepare && bunx tsc --noEmit`, `bun test`, `bunx biome check`,
  `bun run schema:check` green — the schema check must show deprecations only, no breaking change.
- iOS builds; the saga page of a foreign edition screenshotted from preview fixtures.
- No push without the user saying "push".

## Left to the builder

The exact name of the boundary function, the wording of descriptions and deprecation reasons, how
the fake Firestore fixtures are rewritten, and the order of commits.
