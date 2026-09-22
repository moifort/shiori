# Changelog

English is the source of truth. Every served language has its own file, kept in lockstep:
`CHANGELOG.fr.md`. Only consequential changes are logged — a renamed label or a reworded
subtitle has no impact on anyone and stays out.

Each version heading carries the App Store version and its release date: `## 1.0 (2026.10.01)`.
A plain `## Unreleased`, with no date, is allowed for pending work and must be versioned before
the release tag is pushed.

## Unreleased

- After onboarding, the dashboard opens on a short preparation screen while the library is
  set up, waiting on an Audible import long enough for its first books to be there. The
  settings button stays a gear; an import still running afterwards shows as the dashboard's
  leading spinner.
- Subgenres are never translated, and each one knows its language: a scan writes them in the
  language of the edition, an Audible import in the title's, and a reader's typing in the
  language of their app. The suggestions offered while typing are the ones in the app's
  language.
- The library and the Series tab are sorted by date and sectioned by month, as in Vinarium:
  newest first on the day a book was finished, else started, else added, and a saga on its
  latest volume. This replaces the sections by reading status and by genre, and the genre
  view is gone from both toolbars; the dashboard's genres card opens the library.
- The dashboard is drawn from the first launch: an empty library shows every card with a
  sketch of what it will hold, under a prompt to scan the first book. Every list says it is
  empty, or could not load, the same way.
- Onboarding offers to import an Audible library after the first name, and can be skipped.
- A saga's catalogue no longer lists the same volume twice.
- A book can be marked "Abandonné" from its menu when the reader stopped because they did not
  like it. It has its own filter, counts in no reading statistic, and the dashboard counts the
  dropped books in a small tile beside a new favourites tile.
- The Series tab has the library's views and filter: everything or the favourites,
  narrowed to one state. Each row's cover strip lists every volume the series screen does,
  announced volumes and related works included, the ones the reader does not own dimmed
  between the ones they do.
- The series screen follows the book screen: the genre, subgenres and rating sit in the main
  section, with the dates the saga was started, added and finished; the volumes look like the
  library's rows and open the reader's books; and a saga can be deleted with all its books.
- A volume added from the series screen is a full record: the title lookup writes its summary,
  genre, page count and cover, as for a title typed in the add sheet, and the volume takes its
  row in the saga, related works included. It still lands, with what the catalogue knows, when
  no scan is left.
- An audiobook carries a headphones pill on its cover, and a library row shows its reading
  status in the corner. The edit form offers a running time ("14h30") and the narrators for an
  audiobook instead of the page count, and the book screen shows when it was added.
- Subgenres are written with a capital on every word, keeping the capitals they already have
  ("LitRPG").
- Every view of the library, and of the Series tab, shows its last rows at once when switched
  to, with the small refresh spinner on top.
- An Audible import lands in the right genre. Every shelf Amazon files a title on now has
  its say, rather than the first one listed, which was often the catch-all literary rack:
  Fondation is science fiction again, Le Dernier vœu fantasy. Harry Potter and the
  children's and teenage fantasy racks, crime fiction, cozy mysteries and sword and sorcery
  are recognized, and audible.com titles no longer land on unrelated shelves.
- The Series tab is sectioned by genre, and within a genre puts the sagas in progress
  first, then the finished ones, then those not started, the latest change of reading
  status leading each. Every saga is labelled in words with where the reader stands — in
  progress, finished, to read — and shows its volumes as a strip of covers, scrolled
  sideways, each carrying its reading status. The series screen opens on an activity ring
  beside the saga's name, author and size, lists its volumes one per row, says where the
  reader stands with a volume only by the badge on its cover, and edits the genre and
  subgenres of every volume at once.
- A scanned book whose cover Open Library does not have now looks for it on Amazon, by the
  ISBN, before falling back to the typographic placeholder. Books already in the library get
  the same second chance once. The ISBN and page count a scan records are now those of the
  edition photographed, named by its publisher and language, rather than of any edition of
  the book: the Folio pocket no longer takes the cover of the Québec edition.
- The library switches, from its toolbar, between everything, by genre and the favourites,
  and a filter narrows any of them to one reading status. Everything and the favourites are
  sectioned into in progress, to read and finished; the genre view has one section per
  genre, titled without an icon, each row tagged with its status. Sagas are no longer
  gathered: each book sits where its own status puts it and names its saga and volume in a
  tag, the cover badge giving way to the words. Within a status, the book most recently
  started, added or finished comes first. The camera button in the tab bar now opens the
  add sheet — scan, recent photos, a title or a record typed by hand — in place of the
  library's "+" button, and every row shows the heart when the book is a favourite, the
  stars otherwise, never both.
- The book sheet folds its publication facts into the main section, names the volume beside
  the cover, shows the format as a glyph in the corner and opens a genre sheet from its genre
  row. A summary longer than five hundred words folds behind "Lire la suite". The list of
  the other volumes leaves the sheet: the series screen, one tap away, is where the
  catalogue lives.
- A genre or subgenre corrected on one volume is applied to every volume of its saga in the
  library, and the subgenre field proposes the words the reader has already used.
- The dashboard's average rating opens the library on the favourites, and its genre bar on
  the genre view. The listening hours leave the chart of a library with no recording, the
  pages that of a library of recordings only, and the chart remembers which measure was
  chosen across launches.
- A library can be shared with a friend. The reader sends an invitation link, and whoever
  takes it up sees their shelf while they see theirs: it opens both ways at once, and either
  of the two can end it for both. A friend's profile shows what they are reading, their pile,
  their favourites and the sagas they are working through. Books marked "do not share" appear
  nowhere, and no reading note is ever shown.
  Tapping the invitation on an iPhone that has Shiori opens the app on the invitation
  itself, with one tap to accept — and one tap to decline, because the link came from
  somewhere the reader does not control. Without the app it opens the page it always did.
- A Kindle library can be catalogued from the data export Amazon hands its customers. Amazon
  publishes no Kindle library API, so there is no account to connect and no nightly sync: the
  reader asks Amazon for their data once, and hands Shiori the file. The titles it holds are
  listed, the ones already on the shelf ticked off, and the ones kept land on the pile as
  ebooks with their title and author — all a purchase history carries.
- A saga's screen is now a shelf: its volumes side by side in the order of the cycle, the
  ones on the shelf in full colour, the ones still missing as dimmed stand-ins with a button
  to add them, and the ones not out yet marked as such. A bar under the description says how
  far along the published volumes the reader is. Tapping a volume they own opens it.
- The library's "add" button opens a sheet laid out like Vinarium's file sheet: the camera
  and the last photos in one strip, a title to type as remembered — the AI looks the book up
  and proposes the same record a scan would, for one scan of the allowance — and the form
  to fill by hand.
- Shiori appears in the iPhone share sheet. A book's page shared from Safari or the Amazon
  app, a selected title, a photo of a cover — whatever is sent lands in Shiori, and the next
  time it is opened the record is waiting to be reviewed. A shared page is fetched for its
  title, the shop's own name and the format stripped off it; a page that leads nowhere costs
  nothing.
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
