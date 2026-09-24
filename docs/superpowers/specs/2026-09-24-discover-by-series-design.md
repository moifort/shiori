# Découvrir by series — design

Découvrir stops being "the translations of what you read in another language" and becomes
"what is coming next in the sagas you follow", whatever the language. It is laid out as the
Library tab is: a "Livres | Séries" capsule, rows drawn as the Library draws them, and a tap
that opens the very same book and series screens.

## What the reader sees

### Two shelves, one capsule

The `LibraryShelfPicker` capsule (Liquid Glass, floating above the tab bar) is reused as is:
"Livres | Séries", the last one shown kept between visits under its own `AppStorage` key. The
toolbar keeps the book / audiobook format filter and the refresh button.

Both shelves show the same releases, grouped differently, in the same two sections:

- **À venir** — volumes announced with a date, the soonest first.
- **Vous intéresse peut-être** — for now, a book or saga already out in the app's language
  that the reader read in another one (today's "Déjà disponibles en français"). Further rules
  will be added to this section later; it is built so one rule is one function.

The headings "Bientôt en français" and "Déjà disponibles en français" go away.

### Séries shelf

One row per saga **and language**, exactly as the Series tab keys its rows: a saga read in
English whose French translation is announced makes an EN row and a FR row, each with its own
covers. The row is the Series tab's row — title, marks, strip of covers — with the announced
volume dimmed and its date under it ("8 oct."). The subtitle reads "Prochaine sortie · tome 5".

The language is shown only by the existing `LanguageTag`, under the Series tab's rule: shown
for a language other than the app's, absent otherwise. No "· FR" in any label.

A tap pushes the same `SeriesView(seriesId:language:)` the Series tab pushes, with its
first-open behaviour intact (a missing catalogue is built on the spot).

### Livres shelf

One row per release, drawn as the Library's `BookRow`, with the `ReleaseDateBadge` leaf on the
trailing edge for an announced volume. Standalone books read in another language and out in
the app's appear in "Vous intéresse peut-être".

A tap opens the same book screen as the Library, in preview: the book is not in the library,
so its record is **built** on the tap, as a saga's catalogue is on its first opening — the
same web-grounded enrichment a scan runs (cover, synopsis, genre and subgenres, publisher,
pages, ISBN, saga placement), so the screen looks exactly like a book the reader owns. This
holds for a book not out yet: a volume due in a month is described from its announcement
(publisher page, pre-order listings); what nobody knows before release, such as the page
count, is simply absent, as it is on any record missing it.

The screen is `BookPage` itself, not a lighter variant. Only what needs ownership changes:
the reading status, rating and reading dates give way to the release date ("Sort le 8
octobre 2026"), "Ajouter à lire" and "Pas intéressé". Nothing enters the library without the
button.

The preview lookup is shared and cached (keyed on ISBN-13, else title + author + language),
holds no reference to any reader, and **does not spend a scan**: opening previews must not
drain the allowance. Adding the book reuses the preview's data, so it spends nothing either.

### Swipe and alerts

"Pas intéressé" (swipe and context menu) keeps working on both shelves and dismisses the saga
edition, or the standalone book, for good. The release-day push keeps going out, now for any
language the reader follows a saga in.

## Which sagas are watched

Every saga the reader holds in state `in-progress` or `complete`, per edition language. Sagas
the reader unfollowed and sagas not started are left out. For each edition:

- the reader's own language for that saga (the next volume in English, for a saga read in
  English), and
- the app's language, when it differs (the French translation).

Standalone books keep today's rule: watched only when read in another language, for their
translation into the app's.

## Data

### The catalogue carries release dates per language

The watch writes into the shared series catalogue, so the series screen, the saga's state, its
ring and the dashboard all follow without being told.

```ts
type Volume = {
  number?: VolumeNumber
  title: BookTitle
  publishedIn?: Year
  kind: VolumeKind
  /** When this volume came out, or comes out, in each language it was found in:
   *  "2026-10-08", "2026-10" or "2026" — as precisely as it was announced.
   *  Written by the release watch, never by a reader. */
  releases?: Partial<Record<BookLanguage, ReleaseDate>>
  /** Its title in those languages, when it differs from `title`. */
  titles?: Partial<Record<BookLanguage, BookTitle>>
}
```

A volume the watch finds that the catalogue lacks (volume 5, announced) is appended as a
`main` volume at its number. A new optional field: no migration.

### "Out" is judged per edition

`isForthcoming(volume, currentYear)` becomes `isForthcoming(volume, today, language?)`: with a
language and a release date in it, the date decides; otherwise `publishedIn` decides, as today.
The Series tab row, `SeriesView`, the ring and the dashboard pass the row's language.

### The state rule is reversed, on purpose

Today `stateOf` ignores announced volumes so that a reader up to date on a running saga reads
as `complete`. From now on, a volume announced **with an exact day** in the edition's language
counts in the spine: the saga moves from `complete` back to `in-progress` the moment the watch
finds "tome 5, 8 octobre", and the ring reads 4/5. An announcement dated only by month or year
does not count yet, so a distant rumour does not reopen a finished saga. The doc comment on
`stateOf` is rewritten to say so.

### The release watch

`translation-watches` becomes `release-watches`: one shared document per saga edition
(`series--{seriesId}--{language}`) or standalone translation (`book--{shelfKey}--{language}`),
no `userId`, searched again on the web once a week. The prompt changes from "every translated
volume" to "every volume in {language}, out and announced, with its exact date".

After each search, the watch:

1. saves itself (what Découvrir's rows are drawn from, with covers and ISBNs per edition), and
2. merges its dated volumes into the saga's catalogue: `releases[language]`,
   `titles[language]`, and any missing volume appended. The merge only adds or corrects dates;
   it never removes a volume the catalogue already holds.

The budget stays as it is (20 works a reader a day, 5 calls at once, one search per work a
week, shared across readers). Watching every followed saga instead of the foreign-read ones
multiplies the number of searches; a large library is covered over a few days rather than on
first opening. The most recently read sagas go first.

### Covers

Each edition's cover is resolved from its ISBN-13 through the existing cover lookup, and
stored on the watch, so a FR row draws French covers and an EN row English ones. A volume
with no cover found draws the Series tab's placeholder.

### Migration

`translation-watches` documents change shape and key: migration `007` deletes them, and the
next refresh rebuilds them as `release-watches`. `DiscoverFeed.dismissed` keys are rewritten
from `series--{id}` to `series--{id}--{language}` for the language the reader read it in.

## API

```graphql
type Discover {
  preparedAt: DateTime
  canRefresh: Boolean!
  upcoming: [Release!]!   # À venir
  maybe: [Release!]!      # Vous intéresse peut-être
}

type Release {
  key: String!            # what "Pas intéressé" remembers
  kind: ReleaseKind!      # SERIES | BOOK
  seriesId: SeriesId      # for the series screen
  language: BookLanguage! # the edition's language
  title: String!
  author: String
  editions: [ReleaseEdition!]!   # title, volume, format, date, isbn13, coverUrl, audibleUrl
  nextDate: ReleaseDate
}
```

The Séries shelf groups `Release` by key; the Livres shelf flattens their editions. Book
previews are served by a new `bookPreview(isbn13, title, author, language)` query returning a
`Book` shape with no id and its release date, which `BookPage` draws in preview mode. The
built record is cached shared, so the second reader to open it pays nothing; a cached preview
of an announced book is rebuilt once it is out, since its listing then fills in.

## Tests

- Unit: `isForthcoming` per language, `stateOf` with an exact-day announcement (complete →
  in-progress) and with a month-only one (stays complete), the catalogue merge (adds, corrects,
  never removes), the grouping into À venir / Vous intéresse peut-être.
- Integration: a watch refresh writes both the watch and the catalogue; read budgets on
  `discover` (one feed, the books, the watches in one `getAll`); the preview lookup is cached
  and spends no scan; migration 007.
- Feature: `discover` returns FR and EN rows for a saga read in English; `bookPreview`.
- iOS: screenshots of both shelves, the series screen with volume 5 dated, and a book preview,
  for approval before install.

## Out of scope

- New rules for "Vous intéresse peut-être" beyond translations.
- Watching sagas not started or unfollowed.
