# Tasks

Backlog of the work agreed for the current scope, grouped by complexity. A task leaves this
file when it ships; what is not yet decided stays in [roadmap.md](roadmap.md). Where a task
says "as in Vinarium", the reference implementation lives in `../vinarium` and is transposed,
not reinvented.

The tiers: **small** is one view or one resolver, no schema change; **medium** touches the
schema, a domain command, or several screens at once; **large** brings in a new system
(platform extension, cache layer, external source) or a design decision that is still open.

## Small

- [ ] **Library list, heart or stars, never both.** If the book or series is a favourite, show
      the heart only; otherwise show the star rating.
- [ ] **Library list, series section header:** the rating or the heart is right-aligned, on
      the same line as the series title.
- [ ] **Library list, book row:** the rating or the heart is right-aligned on the row.
- [ ] **Library list, no language flag on a book row inside a series section.** The section
      header already carries it; the flag stays on standalone rows only.
- [ ] **Book screen, cap the summary** at a word count, around 500 words.
- [ ] **Book screen, merge the Publication section into the main section.**
- [ ] **Book screen, show the volume number to the right of the cover.**
- [ ] **Book screen, show the book type as an icon** at the top right of the main section.
- [ ] **Series list, remove the small chevrons** and put the status icon at the top right of
      each row.
- [ ] **Dashboard, remember the reading chart metric across launches.** The segmented picker
      of the reading chart widget is a plain `@State` today, so it resets to pages on every
      start. Persist the choice (`@AppStorage`) and restore it on launch.

## Medium

- [ ] **Every CTA that runs an async call or a network request shows a loader** after the
      tap, until the call settles. Small per button, medium because it is an audit of every
      screen.
- [ ] **Adding a series updates the analytics**, including when the series is set from the
      book screen (tap on the record) rather than at scan time.
- [ ] **Lists and the dashboard analytics refresh** after a record is edited or a new book is
      added, without a manual pull.
- [ ] **Library list, sort by last modification.** A series keeps its whole section together,
      placed by its most recent modification; books without a series follow the series
      sections. Do not label the standalone section. Changes the `library` query ordering.
- [ ] **Library list, uniform rows.** Rework the row layout so every list shows the same data
      in the same places.
- [ ] **Book screen, tapping the genre section opens a modal** to change the genre.
- [ ] **Subgenre autocompletion** when the reader types a subgenre. Needs a query over the
      reader's existing subgenres.
- [ ] **A genre or subgenre added, created or edited on a book that belongs to a series is
      applied to every book of that series.** A fan-out write in the book command.
- [ ] **Book screen, remove the "in the same series" section**, back end to front end. That
      list belongs to the series domain and must come from it.
- [ ] **Series screen, rework the layout** and fix the icon + label bugs (size and spacing).
      Propose options that make it more readable.
- [ ] **Dashboard, show the total number of favourites.** Tapping it opens the list of every
      favourite, series included. Needs a new analytics figure and a new list screen.
- [ ] **Library, replace the `+` CTA** with the import entry point styled like the "add a file"
      flow of the Vinarium wine record. That flow also offers to type only a title and let the
      AI do the search. The title-only path is a new scan mutation.

## Large

- [ ] **Pagination** on every list, as in Vinarium. Cursor arguments on every list query,
      client-side page accumulation, and the read-budget tests to match.
- [ ] **Pre-cached screens render their data immediately** with a loader at the top while the
      fresh data loads, as in Vinarium. A persisted Apollo cache and a cache-then-network
      policy on every screen query.
- [ ] **Share sheet import.** Register Shiori as a share target so that a page shared from
      Safari or the Amazon app on iPhone offers the Shiori icon, and the app catalogues a book
      from the shared content. An app extension, a shared container, and a scan from text or
      URL rather than from a photo.
- [ ] **Kindle sync, on the model of the Audible connection.** Constraint recorded in
      [roadmap.md](roadmap.md#batch-6--kindle-import): Amazon publishes no Kindle library API
      and the Audible credentials do not reach Kindle, so the Audible design (sign-in, nightly
      sync, ASIN matching) cannot be transposed as is. Settle the source first: the Amazon data
      export, the Kindle Cloud Reader session, or a paid third party.
