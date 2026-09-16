# Home dashboard — design

> Written 2026.09.15. Replaces the "currently reading" list of the Home tab with a dashboard
> of reading statistics, in the spirit of the iOS Fitness app. Depends on the genre refactor
> ([2026-09-15-genres-design.md](2026-09-15-genres-design.md)).

## 1. What the reader sees

Top to bottom, in one scroll view. Every widget is drawn from the first book on, so the reader
sees what the dashboard will hold; a widget with nothing to show yet says in place what will
fill it ("Terminez un livre pour le retrouver ici."). The chart starts at zero: six empty years
on the books chart, twelve empty months on the pages chart. The two tiles read a dash.

| Widget | Content |
|---|---|
| Reading chart | A toggle between **Books** (books read per year) and **Pages** (pages read per month of the current year). Bar chart; the unfinished period (this year, this month) is drawn paler. |
| Currently reading | Horizontal row of covers, most recently started first, each with "depuis N j". The row overflows the card edge so a cropped cover hints at scrolling. Tapping the header opens the Library tab filtered on `reading`. |
| You might like to read | Same row, six `to-read` books drawn at random, the draw stable for the day. |
| Last finished | Cover, title, author, rating, "lu en N jours", "il y a N j". |
| Trends | Pages per day and median days to finish a book, this year to date against the same period last year, with an up/down arrow. No arrow when last year has no data. |
| To-read pile · Average rating | Two tiles: the pile size with "~ N mois au rythme actuel"; the average rating with the count of rated books. |
| Genres read this year | Segmented horizontal bar with a legend: top four genres, the rest and `other` grouped as "Autres". |
| Series in progress | Up to three sagas in progress, volumes read / main volumes known, as progress bars. Header opens the Series tab. |

A library with no book at all shows an invitation to scan a first book instead.

## 2. Statistics rules

All are pure functions in `server/domain/analytics/business-rules.ts`.

- **Books read per year** — `read` books grouped by the year of `finishedAt`. Always the last
  six years, the current one included, empty years at zero: a first year alone would be one
  wide bar.
- **Pages per month** — each `read` book with a `pageCount` spreads its pages evenly over the
  calendar days from `startedAt` to `finishedAt` inclusive; days are summed by month. A book
  started in December and finished in January counts on both years. Books without a page
  count are ignored.
- **Pages per day (trend)** — pages attributed to days from January 1st to today, divided by
  the number of those days; compared to the same span last year.
- **Days to finish (trend)** — median of `finishedAt − startedAt` in whole days (minimum 1)
  over books finished this year to date; compared to books finished in the same span last
  year. Median, not mean: one book abandoned for six months would skew a mean.
- **To-read pile** — count of `to-read` books. Months to clear it = pile ÷ (books finished in
  the last 365 days ÷ 12), rounded up; hidden when that pace is zero.
- **Average rating** — mean of ratings over `read` books that carry one, one decimal.
- **Genres** — `read` books finished this year, counted by `genre`; books without a genre
  count as `other`.
- **Series in progress** — sagas where the reader has at least one book, whose catalogue state
  is `in-progress` (`stateOf`), ordered by the most recent activity (`finishedAt` or
  `startedAt` of their books), three at most.
- **Suggestions** — `to-read` books shuffled with a seed made of `userId` and the local date.

Every "day", "month" and "year" is taken in the reader's time zone, passed by the app as an
IANA identifier. Without it a book finished on December 31st at 23:00 in Paris lands on the
wrong year.

## 3. Storage: a materialized view

The dashboard reads **one document**, `analytics/{userId}`, instead of the whole library.

### What the document holds

Raw aggregates, not rendered values, so that anything depending on the current date is
computed on read and the view never goes stale by the calendar alone:

- `finishes`: one entry per `read` book — local start and finish dates (`2026-09-14`, in the
  time zone of the refresh), page count, genre, rating. Books per year, pages per month and
  per day, both trends, the genre breakdown, the pace and the average are all derived from it
  on read; a 300-book library spreads over a few thousand days, which is nothing to walk.
- `reading`, `toRead`, `lastFinished`: short book cards — id, title, authors, `startedAt` /
  `finishedAt`, rating, cover path or published cover URL.
- `series`: progress of every saga in progress — id, name, volumes read, main volumes known,
  last activity.
- `timeZone`, `refreshedAt`, `stale`.

Covers are signed on read, because signed URLs expire. At most a dozen are drawn, signed
concurrently.

### Keeping it fresh

**Full recompute on every write.** After any change to a book, the view is rebuilt from all
the reader's books and written whole. Writes are rare and the home screen is read often, so
the extra query is paid on the cheap side; and a view rebuilt from source cannot drift, so a
bug in a rule is corrected by the next write.

- `BookUseCase` (new, `server/domain/book/use-case.ts`) wraps `add`, `edit`, `setStatus`,
  `rate`, `unrate`, `annotate`, `setHidden` and `remove`. Each one writes the book **and**
  marks the view `stale: true` in the same batch, then calls `AnalyticsCommand.refresh`,
  which recomputes and writes `stale: false`. The GraphQL mutations call the use case, never
  `BookCommand` directly.
- The refresh uses the time zone stored on the view (the app's, from its last dashboard
  read), `UTC` for a view that does not exist yet.
- If the refresh fails, the view stays `stale`. `AnalyticsQuery.dashboard` rebuilds a view
  that is missing, stale, or stored under a different time zone than the one requested,
  before answering. The dashboard is never wrong, at worst slow once.
- Account deletion removes `analytics/{userId}` alongside the books.
- The series totals are copied at refresh time. A shared catalogue enriched later leaves the
  progress bar behind until the reader's next book write — accepted: catalogues rarely change,
  and refreshing every reader of a saga would mean scanning users.

### Read budget

- Dashboard, fresh view: 1 document read.
- Dashboard, stale view: 1 document read + 1 query on `books` + 1 batched read of the series
  in progress.
- Book write: the existing reads + 1 query on `books` + the series read.

## 4. GraphQL

`dashboard(timeZone: TimeZone!): Dashboard!`, in the `analytics` domain. A `TimeZone` scalar
validates the IANA identifier through `Intl`. Types: `Dashboard`, `YearCount`, `MonthCount`,
`Trend` (current, previous nullable), `GenreCount`, `SeriesProgress`, and a `DashboardBook`
card (id, title, authors, coverUrl, rating, startedAt, finishedAt). Suggestions and currently
reading are capped server-side (six and ten).

## 5. iOS

`Features/Home/`, transposed from Vinarium's `Dashboard`:

| File | Role |
|---|---|
| `HomeAPI.swift` | the `Dashboard` query, called with `TimeZone.current.identifier` |
| `HomeViewModel.swift` | loading, error, refresh |
| `HomeView.swift` | coordinator: sheets, tab switching |
| `components/pages/HomePage.swift` | stateless page, previews with data and empty |
| `components/organisms/` | `ReadingChartWidget`, `BookShelfSection` (reading and suggestions), `LastFinishedCard`, `TrendsWidget`, `StatTilesRow`, `GenresWidget`, `SeriesProgressWidget` |
| `components/molecules/` | `WidgetCard`, `CoverTile`, `SegmentedBar` |

- Charts use Swift Charts. The style follows the system appearance; the Fitness-like vivid
  colours are on figures and charts, cards use `secondarySystemGroupedBackground`.
- Tapping a cover opens `BookView` as a sheet; a change reloads the dashboard.
- "Currently reading" header: `ContentView` switches to the Library tab and hands it a
  `reading` filter. "Series in progress" header switches to the Series tab; a row opens
  `SeriesView`.
- Pull to refresh, and a reload each time the Home tab reappears.

## 6. Tests

- Unit: every rule of section 2, including the cross-year spread, empty years, median, zero
  pace, time zone boundary, and the stable daily shuffle.
- Integration: a book write leaves the view fresh; a failed refresh leaves it stale and the
  dashboard rebuilds it; a fresh dashboard read costs one document read and no query; account
  deletion removes the view.
- Feat: `dashboard` answers the expected shape; every book mutation refreshes the view.
