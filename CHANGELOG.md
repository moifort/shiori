# Changelog

English is the source of truth. Every served language has its own file, kept in lockstep:
`CHANGELOG.fr.md`. Only consequential changes are logged — a renamed label or a reworded
subtitle has no impact on anyone and stays out.

Each version heading carries the App Store version and its release date: `## 1.0 (2026.10.01)`.
A plain `## Unreleased`, with no date, is allowed for pending work and must be versioned before
the release tag is pushed.

## Unreleased

- The library is ordered by what was touched last: the saga whose volume was just rated,
  moved or corrected sits on top, whole, and the shelf of books outside any series trails
  the sagas without a heading of its own. A saga heading now carries the heart or the stars
  the reader gave the saga, on the right, and every row keeps its own in the same place:
  the heart when the book is a favourite, the stars otherwise, never both.
- The book sheet folds its publication facts into the main section, names the volume beside
  the cover, shows the format as a glyph in the corner and opens a genre sheet from its genre
  row. A summary longer than five hundred words folds behind "Lire la suite". The list of
  the other volumes leaves the sheet: the series screen, one tap away, is where the
  catalogue lives.
- A genre or subgenre corrected on one volume is applied to every volume of its saga in the
  library, and the subgenre field proposes the words the reader has already used.
- The dashboard counts the favourites, books and sagas together, in a tile that opens the
  list of everything hearted. The listening hours leave the chart of a library with no
  recording, and the chart remembers which measure was chosen across launches.
- The library's "add" button opens a sheet laid out like Vinarium's file sheet: the camera
  and the last photos in one strip, a title to type as remembered — the AI looks the book up
  and proposes the same record a scan would, for one scan of the allowance — and the form
  to fill by hand.
- The settings, behind a gear on the dashboard: the profile with sign-out and account
  deletion, the subscription, the release notes, a form to write to us, and the Audible
  connection, which leaves the imports menu.
- The library and the series tab load a page at a time and fetch the next one as the reader
  nears the end of the list, so a library of three hundred books draws as fast as one of
  thirty.
- The library, the series and the dashboard open on what they showed last time and refresh
  underneath, under a spinner at the top, rather than on a loader. Every button that waits
  on the network spins from the tap, and every list redraws after any change made elsewhere.

- A saga imported from Audible now has a series screen. Until now only a scan built a saga's
  catalogue, so every saga an import named opened on "not catalogued" for good. The catalogue
  is now built the first time the saga is opened, from the volume already in the library; that
  first opening takes a few seconds, and every later one is immediate.
- Shiori has an icon: a red bookmark ribbon hanging on a cream page. The same ribbon is the
  app's opening animation, dropping into place while the library loads, and the mark on the
  sign-in and welcome screens.
- An Audible library now keeps itself up to date. Each night Shiori catalogues the titles
  bought since the last pass, and moves an imported book to the status Audible reports — a
  title finished there is marked read here, on the date it was actually finished, and one it
  says was never opened goes back to the pile. Ratings, notes and hidden books are never
  touched, and a book catalogued from the printed edition is never moved. Turn the sync off
  from the Audible card to go back to importing by hand, or ask for a pass there and then
  instead of waiting for the night.
- Imports have their own menu on the Home tab, opening a card for each source. The Audible card
  gathers what used to be scattered: which store the account points at, when it was linked,
  whether it syncs each night and when it last did, how much of the library is already
  catalogued, and the button that asks for a pass now. Picking titles by hand is one tap
  further in, because a connected library keeps itself up to date. The entry in the Library
  tab's add menu is gone; importing a whole library is managing an account, not adding a book.
- An audiobook imported from Audible arrives with its genre, read off the shelf Amazon files it
  on rather than left for the reader to set title by title. A shelf that names an audience or a
  theme rather than a kind of story — "Jeunesse", "LGBTQ+" — is kept as a subgenre instead, and
  alongside the genre rather than in its place: a young-adult thriller is a thriller filed under
  "Young adult". Books imported before this keep whatever genre they were given by hand.
- A translated audiobook is no longer credited to its translator. Audible files every
  contributor as an author and tags the role inside the name, so books arrived showing
  "Danusia Stok - translator" on the book screen as if she had written them.
- A saga can now be rated on its own, from one to five stars, and kept as a favourite — as can
  a book. The saga rating is a judgement of the cycle rather than the average of its volumes,
  and the heart is independent of the stars on both: a five-star book one never wants to open
  again and a three-star one kept for what it meant are both real.
- The language of an edition is read off the cover during a scan, and taken from Audible on an
  import. Each book carries its flag in the library, and a saga held in more than one language
  is now shelved once per language — "Dune" in French and "Dune" in English are two sections
  and two rows in the Series tab, each with its flag. Books catalogued before this show no
  flag until the language is set by hand from the book screen.
- A library row now says what the book is about, with the genre and its icon under the stars
  and, beside it, the book's most telling subgenre — a scan now orders the subgenres it finds
  so that the first one is the one that describes the book best. The row also marks an
  audiobook with a headphones symbol.
- An audiobook credits its narrators and shows its running time on the book screen, both taken
  from Audible on import.
- Sagas imported from Audible, and sagas of books added by hand, now appear in the Series tab.
  They were missing entirely: the tab listed only sagas some scan had described, and neither an
  import nor a manual entry ever calls for a description.

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
- A flag now marks only the editions in a language other than the phone's. A reader whose
  iPhone is in French owns a French library by default, and a 🇫🇷 on every row said nothing;
  the flag is kept for the exception, the English or Japanese edition among them.
