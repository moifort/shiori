# Languages, narrators, series opinions — design

Five changes asked for together. They share no code, so they ship in order, each verified on
its own: the Audible series bug first because it is a defect, then the small additions, then
the two that touch the data model.

| # | Change | Weight |
|---|---|---|
| 1 | Sagas imported from Audible never reach the Series tab | defect |
| 2 | The narrator of an audiobook | small |
| 3 | The genre on a library row | small |
| 4 | The language of an edition, its flag, and the split it forces on sagas | large |
| 5 | Rating and favouriting a saga, favouriting a book | large |

## 1. A saga imported from Audible is invisible

`mySeries` starts from `SeriesQuery.byIds`, so a saga with no catalogue document does not
exist as far as the Series tab is concerned. The Audible import writes `book.series` and never
calls Gemini, so none of its sagas have one. A book added by hand has the same problem; the
defect was only noticed through the import.

The fix reverses the direction: **the reader's own books are the source of the followed sagas**,
and the shared catalogue only enriches them. That is what the denormalized `SeriesMembership`
is for — the directive already says grouping a library must not read one catalogue document
per row.

Cataloguing every saga at import time was rejected: an import of eighty titles can carry
thirty sagas, and that is thirty grounded Gemini calls charged at once to a reader who asked
for an import, not for a catalogue.

Consequences:

- `FollowedSeries` stops being `{ series: Series }`. It becomes the identity the books carry —
  `id`, `name`, the first author — plus `catalogue: Series | null`.
- `state` becomes nullable. Without a catalogue there is no list of published volumes, so
  whether the saga is complete is unknown, and `in-progress` would be a guess dressed as a
  fact.
- Opening an uncatalogued saga catalogues it on demand, one grounded call, debited from the
  scan quota like any other. That keeps the cost attached to a reader who asked to see the
  saga.

  **Not built.** The tab lists the saga and the heart works on its screen, but the screen
  still says "Série non cataloguée" and offers no way to describe it. Cataloguing on demand
  needs a public entry point on `Scan`, which today only exposes `scanWithCache`, and a quota
  debit outside the scan mutation. Deferred rather than rushed.

This is a breaking GraphQL change; the iOS `Series.graphql` operations and the generated
Apollo code follow.

## 2. The narrator

New brand `NarratorName` (1–200 characters), and `narrators: NarratorName[]` on `Book`,
modelled on `subgenres` — a plain array, defaulted to empty on read, so no migration.

`ImportableBook.narrators` is already collected and then dropped by `bookFrom`; it is carried
onto the record instead, through the brand's constructor like every other imported field.
Editable by hand. Drawn on the book screen under the authors, only when the format is
`audiobook`: a printed book has no narrator and an empty row would say nothing.

## 3. The genre on a library row

`Book.genre` already exists and is already stored. It is simply not asked for by the `Library`
query and not drawn. The field joins the fragment, and the row gains a label with one SF
Symbol per genre — a table of twenty-two entries that lives in the app, not on the server:
the server has no business knowing what a glyph is.

A book with no genre draws no row. Audible imports have none by design, so a library built
mostly from Audible shows this rarely until those books are classified by hand.

## 4. The language of an edition

### The type

`Book.language` is typed `Language`, which is `'fr' | 'en'` — the set of languages the *app*
is localized into. Reusing it for the language of a printed edition was wrong, and nothing
ever wrote the field, so it is replaced rather than migrated.

New brand `BookLanguage` over a **closed list** of sixteen: `fr en es de it pt nl sv pl ru uk
tr ar ja zh ko`. Closed for the reason `GENRES` is closed, plus one of its own: a flag is
drawn from a list that is known, and an arbitrary ISO code has no glyph to draw.

No `other`. It was in the first draft and taken out during the build: it draws no flag and
groups with the unrecorded books, so it would be a second way of saying "unknown" — an
edition in a language off the list simply keeps none.

A language is not a country and the flags are a convenience, not a claim: `en` shows the
Union Jack, `pt` the Portuguese flag, `ar` the Saudi one.

### Where it comes from

The language of an edition is legible on its cover, so it is read in the **vision** step of
the scan, not the enrichment step: the enrichment step is grounded and would answer about the
work rather than about the object photographed.

Audible exposes `item.language`; it is mapped through the same constructor and dropped when
it does not match the list. Correctable by hand on the book screen.

Every book already in a library has no language and keeps none until it is corrected or
re-scanned. That is visible as a group with no flag, which is honest.

### What it changes on screen

- A flag on the library row, right-hand side, beside the `hidden` eye.
- **The grouping key of a saga becomes `(seriesId, language)`.** A reader holding *Dune* in
  both languages sees two sections, "Dune 🇫🇷" then "Dune 🇬🇧", each with its own volumes.
  `LibrarySection.series` carries the language, and `mySeries` returns one entry per pair.
- The flag sits to the right of the saga's name, in the library heading and in the Series tab.

The shared catalogue is **not** keyed by language. One saga, one document, paid once, exactly
as the directive requires. The split is a presentation of the reader's own books.

No language filter. The split already makes every language visible, and a filter would be a
second way to do the same thing.

## 5. Rating a saga, favouriting a book

### On a book

`favorite?: boolean`, the Vinarium model: **decoupled from the star rating**, because a
five-star book one never wants to see again and a three-star one kept for sentiment are both
real. A heart in the book screen's primary toolbar slot, and `heart.fill` on the library row.

### On a saga

An opinion belongs to a reader; `series/{seriesKey}` holds no reference to any reader and must
not start holding one. So the opinion lives in its own domain:
`server/domain/series-opinion/`, flat collection `series-opinions`, document
`${userId}--${seriesId}`, fields `rating?` and `favorite?`. `series` stays a fact about the
world.

The rating is the reader's judgement of the saga and is deliberately **not** the average of
their volume ratings — a saga can be worth more or less than its books.

**The opinion is held per saga, not per `(saga, language)`.** The split of section 4 is about
editions on a shelf; an opinion is about the work. "Dune 🇫🇷" and "Dune 🇬🇧" show the same
stars.

## Migrations

None. Every field added is a new optional field or a new collection, and `Book.language` is
replaced while no document holds it.

## Build order

1. The Audible series defect — done, minus the on-demand cataloguing noted above
2. The narrator — done, and the running time joined it on the book screen, along with a
   headphones marker on the library row
3. The genre on the row — done, reusing the `BookGenre.symbol` table that already existed
4. The language, its flag, and the saga split — done
5. Book favourite, then saga opinion — done
