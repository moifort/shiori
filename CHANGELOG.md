# Changelog

English is the source of truth. Every served language has its own file, kept in lockstep:
`CHANGELOG.fr.md`. Only consequential changes are logged — a renamed label or a reworded
subtitle has no impact on anyone and stays out.

Each version heading carries the App Store version and its release date: `## 1.0 (2026.10.01)`.
A plain `## Unreleased`, with no date, is allowed for pending work and must be versioned before
the release tag is pushed.

## Unreleased

- The reading chart on the home screen counts hours listened as well as books and pages: a
  third tab draws the audiobook hours of each month, taken from the running time Audible
  reports for every title imported. Each bar now carries its own figure, and the yearly view
  covers nine years instead of six.
- An Audible library can be imported into Shiori. Connect the Amazon account once from
  Settings, pick the marketplace, and the whole library is listed with its covers, sagas and
  listening progress; tick the titles to catalogue and they land as audiobooks, finished ones
  keeping the date they were actually finished. Titles already in the library are shown
  already ticked off, so importing twice creates no duplicates. An import costs no scan.
- Loading screens now show a heavy tome being marked: a ribbon drops into the gutter and
  the book closes on it, in place of the turning page.
- While a scan runs, the waiting screen shows the photo just taken framed as a book cover,
  swept top to bottom by a beam of light, instead of a generic loader.
- A scan no longer fails after a minute when the models are slow to answer, and an analysis
  that does fail can be run again on the same photo without spending another scan.
- The home screen is now a reading dashboard: books read per year and pages per month, the
  books in progress, a few picks from the to-read pile, the last book finished, trends against
  last year, the pile and the average rating, the genres read this year, and the sagas in
  progress.
- Every book is filed under one genre from a fixed list, with up to three free subgenres
  beside it. Both can be corrected from the book sheet.
- Scanned books now show their published cover, found from the ISBN. A book with no known
  cover keeps its initials.
- Every fact on a book can now be corrected from its sheet with "Edit": title, authors,
  format, rating, synopsis, publisher, year, pages, genres and ISBN. A field can be emptied,
  and a rating taken back.
