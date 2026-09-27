# Découvrir by author — design

Découvrir gains a third shelf, **Auteurs**, beside Livres and Séries: what is coming next, and
what just came out, from the authors the reader holds, outside the sagas the Séries shelf
already watches. It is the Authors spec's lot 2, with the audience widened from the loved
authors to every author the reader has not given up on.

## What the reader sees

- The capsule reads "Livres | Séries | Auteurs" (`LibraryShelf.authors`, already the Library's
  third shelf). The toolbar's Livre / Audio filter applies to it as to the other two.
- Two sections, as on the Séries shelf: **Nouvelles parutions** (out in the last 7 days, the
  newest first) and **Prochaines sorties** (announced, the soonest first).
- A row is the Library's `AuthorRow` — portrait or initials, name, heart or stars, "14 livres,
  3 séries", strip of covers — with an orange line under it, as `SagaReleasesSummary` does:
  "À venir : {titre}" among the announcements, "Disponible : {titre}, {titre}" among the new
  releases. The date sits on the line of the next title.
- A tap opens **the same `AuthorView(key:name:isSheet: true)`** the Library's Authors shelf
  opens, as a sheet. A long press offers "Ouvrir dans Audible" for a recording Audible
  confirmed.
- The Livres shelf is unchanged: author releases show on the Auteurs shelf only.
- No push alert and no digest entry for an author's release in this lot.

## Which authors are watched, and in which format

Every author the reader holds a book of (`shelvedAuthorsOf`), **except** one whose every book
is `dropped`. For each, only the formats the reader holds of them:

- a book or an ebook of theirs → the author is watched in print (`book`);
- an audiobook of theirs → watched in audio (`audiobook`);
- both → both, each its own watch.

The language of a watch is the main language of the reader's books of that author **in that
format** (`mainLanguageOf`). A format whose books record no language is not watched.

## What counts as an author's release

A work of the author, in that language and format, out in the last 7 days or announced, that:

- does not belong to a saga the reader holds anything of, followed or set aside (its folded
  saga name matches none of the reader's sagas, read or heard — the name alone, since a saga
  named by an Audible import is not keyed on its name and author), and
- is not a book the reader already holds (folded title, as `worksNotHeldOf` matches).

So a new standalone and the first volume of a new saga show; volume 7 of a followed saga stays
on the Séries shelf alone.

## Data

### The watch: `author-watches/{key}`

Shared, holding no reference to any reader, keyed `{authorKey}--{format}--{language}`, so every
reader who follows the same author in the same edition converges on one document and the
grounded call is paid once a week.

```ts
type AuthorWatch = {
  key: string
  authorKey: AuthorKey
  name: AuthorName
  format: ReleaseFormat
  language: BookLanguage
  checkedAt: Date
  /** The author's works in that edition out in the last months or announced. */
  works: FoundWork[]
}

type FoundWork = {
  title: BookTitle
  date?: ReleaseDate
  isbn13?: Isbn13
  asin?: AudibleAsin        // kept only once Audible's catalogue confirms it
  coverUrl?: CoverUrl       // resolved from the ISBN, as a saga volume's is
  seriesName?: SeriesName   // what the "outside followed sagas" filter reads
  volume?: VolumeNumber
}
```

A new collection: no migration.

### The reader

`DiscoveryReader` gains an optional `authors: WatchedAuthor[]`, worked out with the sagas when
the tab opens and once a day by the hourly pass. Optional field: no migration.

### The lookup

One grounded call per watch (`step: 'discovery-author-releases'`): "every book by {author} in
{language}, {format}, out since {today − 3 months} or announced, with its exact date", as
`releasesPrompt` asks for a saga. Print dates are confirmed on Amazon by ISBN and covers
resolved, audio ASINs confirmed on Audible — the same helpers the saga lookup uses. A fresh
search is merged over the last one (`mergedVolumes`' rule, on the folded title).

### The passes

- `discover` reads the author watches in one `getAll` beside the saga watches.
- `lookUpUnwatched` (the first look) looks up the unwatched sagas first, then the unwatched
  authors of the format, within the same 90 s budget.
- The hourly pass looks up the due author watches after the due saga watches, within the same
  budget, the never-looked-up first.

## API

```graphql
type Discovery {
  ...
  authors: [AuthorDiscovery!]!
}

type AuthorDiscovery {
  author: FollowedAuthor!          # the Library's Authors shelf row
  next: DiscoveredWork             # soonest announced
  recent: [DiscoveredWork!]!       # out in the last 7 days, newest first
}

type DiscoveredWork { title, date, isbn13, coverUrl, audibleUrl, seriesName, volume }
```

`unwatched` and `followed` count authors as well as sagas, so the app still looks the
unwatched up at once and opens on the other format when this one follows nothing.

## Tests

- Unit: `watchedAuthorsOf` (print only, audio only, both; all books dropped → none; language
  per format), `authorReleasesOf` (next / recent, followed saga excluded, held title excluded,
  new saga's first volume kept), the merge.
- Integration: `discover` returns author rows with the author watches read in one `getAll`;
  `lookUpUnwatched` writes an author watch; the hourly pass looks due authors up.
- Feature: `discovery { authors { author { key } next { title } } }`.
- iOS: screenshot of the Auteurs shelf, and the author sheet opened from it, for approval.

## Out of scope

- Push alerts and the weekly digest for author releases.
- Author releases on the Livres shelf.
- A "Sorties" section on the author page.
