# Tasks

Backlog of the work agreed for the current scope, grouped by complexity. A task leaves this
file when it ships; what is not yet decided stays in [roadmap.md](roadmap.md). Where a task
says "as in Vinarium", the reference implementation lives in `../vinarium` and is transposed,
not reinvented.

The tiers: **small** is one view or one resolver, no schema change; **medium** touches the
schema, a domain command, or several screens at once; **large** brings in a new system
(platform extension, cache layer, external source) or a design decision that is still open.

## Small

- [x] **Every CTA that runs an async call or a network request shows a loader** after the
      tap, until the call settles.
- [x] **Library list, heart or stars, never both.** If the book or series is a favourite, show
      the heart only; otherwise show the star rating.
- [x] **Library list, series section header:** the rating or the heart is right-aligned, on
      the same line as the series title.
- [x] **Library list, book row:** the rating or the heart is right-aligned on the row.
- [x] **Library list, no language flag on a book row inside a series section.** The section
      header already carries it; the flag stays on standalone rows only.
- [x] **Book screen, cap the summary** at a word count, around 500 words.
- [x] **Book screen, merge the Publication section into the main section.**
- [x] **Book screen, show the volume number to the right of the cover.**
- [x] **Book screen, show the book type as an icon** at the top right of the main section.
- [x] **Series list, remove the small chevrons** and put the status icon at the top right of
      each row.
- [x] **Dashboard, hide the listening hours when the library holds no audiobook.** The
      "Heures" segment of the reading chart widget disappears, and a persisted choice of that
      metric falls back to pages.
- [x] **Dashboard, remember the reading chart metric across launches.** The segmented picker
      of the reading chart widget is a plain `@State` today, so it resets to pages on every
      start. Persist the choice (`@AppStorage`) and restore it on launch.

## Medium

- [x] **Adding a series updates the analytics**, including when the series is set from the
      book screen (tap on the record) rather than at scan time.
- [x] **Lists and the dashboard analytics refresh** after a record is edited or a new book is
      added, without a manual pull.
- [x] **Library list, sort by last modification.** A series keeps its whole section together,
      placed by its most recent modification; books without a series follow the series
      sections. Do not label the standalone section. Changes the `library` query ordering.
- [x] **Library list, uniform rows.** Rework the row layout so every list shows the same data
      in the same places.
- [x] **Book screen, tapping the genre section opens a modal** to change the genre.
- [x] **Subgenre autocompletion** when the reader types a subgenre. Needs a query over the
      reader's existing subgenres.
- [x] **A genre or subgenre added, created or edited on a book that belongs to a series is
      applied to every book of that series.** A fan-out write in the book command.
- [x] **Book screen, remove the "in the same series" section**, back end to front end. That
      list belongs to the series domain and must come from it.
- [ ] **Series screen, rework the layout** and fix the icon + label bugs (size and spacing).
      Propose options that make it more readable.
- [x] **Dashboard, show the total number of favourites.** Tapping it opens the list of every
      favourite, series included. Needs a new analytics figure and a new list screen.
- [x] **Settings screen as in Vinarium, reached from the dashboard.** Replace the "Imports"
      menu in the dashboard toolbar with a settings entry, and move the Audible connection
      into that screen. Copy every Vinarium settings menu, including the Sentry user feedback
      form (the `sendFeedback` helper exists without a screen today), except the admin
      section with the platform statistics.
- [ ] **Paywall as in Vinarium, and revisit the subscription prices.** Rebuild the premium
      sheet on the Vinarium paywall (layout, copy, trial and plan presentation). Prices are
      2.99 a month and 24.99 a year with a one-week trial today, in the StoreKit configuration
      only: the App Store Connect app record does not exist yet (see
      [roadmap.md](roadmap.md#resolved-sign-in-with-apple)). Decide the new tiers first, then
      declare the subscription group and both products with those prices when the app record
      is created, and keep the StoreKit file in lockstep.
- [ ] **Library, replace the `+` CTA** with the import entry point styled like the "add a file"
      flow of the Vinarium wine record. That flow also offers to type only a title and let the
      AI do the search. The title-only path is a new scan mutation.

## Large

- [ ] **Pagination** on every list, as in Vinarium. Cursor arguments on every list query,
      client-side page accumulation, and the read-budget tests to match.
- [x] **Pre-cached screens render their data immediately** with a loader at the top while the
      fresh data loads, as in Vinarium. A persisted Apollo cache and a cache-then-network
      policy on every screen query.
- [ ] **Share sheet import.** Register Shiori as a share target so that a page shared from
      Safari or the Amazon app on iPhone offers the Shiori icon, and the app catalogues a book
      from the shared content. An app extension, a shared container, and a scan from text or
      URL rather than from a photo.
- [ ] **Share a profile with friends.** A new screen lists the reader's friends; opening one
      shows their books in progress and series in progress, their favourites, and their
      reading pile. This is batch 3 of [roadmap.md](roadmap.md#batch-3--sharing) with a
      friend list on top: it needs an invitation and acceptance flow, a friendship record, a
      query that reads another reader's books under the `hidden` rule, and it exposes books
      only, never the series catalogue.
- [ ] **Kindle sync, on the model of the Audible connection.** Constraint recorded in
      [roadmap.md](roadmap.md#batch-6--kindle-import): Amazon publishes no Kindle library API
      and the Audible credentials do not reach Kindle, so the Audible design (sign-in, nightly
      sync, ASIN matching) cannot be transposed as is. Settle the source first: the Amazon data
      export, the Kindle Cloud Reader session, or a paid third party.
