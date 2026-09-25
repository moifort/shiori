# Authors — design

The Library tab's third shelf, Authors, lists every author the reader holds a book of, the
loved ones first. This spec covers what opens when an author is touched (lot 1), and records
the release watch that will feed it later (lot 2).

## Already built: the list

- `myAuthorsPage` ranks the authors derived from the books and the saga opinions: hearts
  (hearted books plus hearted sagas), then the mean of the stars, then the books held, then
  the name. Nothing is stored.
- A row: initials, name, hearts or mean stars in the corner, "14 livres, 3 séries", then every
  book as a cover with its reading status. Full-width separators.

## Lot 1 — the author page

### Shared catalogue: `authors/{authorKey}`

Modelled on `series/{seriesKey}`: a fact about the world, holding no reference to any reader,
keyed by the folded name (`authorKeyOf`) so two readers converge on one document and the
model call behind it is paid once.

| Field | |
|---|---|
| `key`, `name` | the key and the spelling the catalogue was built from |
| `nationality?`, `birthYear?`, `deathYear?` | as the web says |
| `biography?` | a few sentences, in the language of whoever opened the page first |
| `portraitUrl?` | Wikipedia's image of the author, HTTPS |
| `series[]` | each saga they wrote: `name`, `volumeCount?`, `firstVolumeTitle?` |
| `books[]` | their books outside any saga: `title`, `year?` |
| `cataloguedAt` | |

### Built on the first opening

`AuthorUseCase.page(userId, key, language)` builds the catalogue when it is missing:

1. The stored catalogue, when there is one.
2. Otherwise the reader must hold a book of the author — nothing to ask about otherwise. One
   grounded Gemini call (`step: 'author'`) returns the fields above plus the title of the
   author's Wikipedia page.
3. The portrait is read from Wikipedia's REST summary of that page (`thumbnail`, else
   `originalimage`), never from a URL the model wrote. No page, no image: the initials stay.
4. Stored, usage recorded. A failed call stores nothing and the next opening tries again.

The Authors list reads the page's catalogues in one getAll and draws the portrait instead of
the initials once an author has one.

### The screen: `authorPage(key)`

One request: the catalogue (built if missing), and from the reader's library —

- **Figures**: hearts, mean stars, books read (a single total).
- **Sagas**: the reader's sagas of this author, as the Series tab draws them (cover strip,
  state, opinion), followed first; then the catalogue's other sagas, not held, each with its
  saga id (`seriesKeyOf(name, author)`), volume count and first volume title.
- **Books**: the reader's books of this author outside any saga, read first; then the
  catalogue's books outside any saga the reader does not hold, matched on the folded title.

### iOS

- A row of the Authors list opens `AuthorView`. The first opening waits up to 120 s, as a
  saga's does, under "Chargement…".
- Header: portrait (or initials), name, nationality and birth, "14 livres, 3 séries",
  biography; then hearts, mean stars, books read.
- A **Livre / Audio** switch right under the header filters every section below it: the
  volumes and books held in that format; what the reader does not hold has no format and
  shows in both. It opens on the format the reader holds most of this author in.
- **Séries**: held sagas as `SeriesRow`, opening the saga screen; sagas not held as a row
  with dimmed placeholder covers and a `+`.
- **Livres**: held books outside any saga, read first, then the others dimmed with a `+`.
- A `+` adds to the reader's pile ("À lire"), in the format of the switch, as the saga
  screen adds a missing volume: a title lookup first, the saga membership filed whatever the
  lookup answered. For a saga, its first volume.

## Lot 2 — the author release watch (later)

A third kind of watched work in Découvrir, beside the saga and the translated book: the
author. The Découvrir scheduler looks each one up weekly, shared between readers, never on a
click. Only the authors the reader loves are watched: a heart, or a mean of four stars or
more. The author page gains a **Sorties** section between the switch and the sagas, showing
the next and the recent releases — the author watch's and the saga watches' — in the format
of the switch.
