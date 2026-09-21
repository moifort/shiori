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
- [ ] **Series screen, rework it around a shelf of covers.** Decided: the volumes become a
      horizontal shelf, as the dashboard draws its shelves. A volume the reader does not own
      has no cover — the catalogue holds a title, a year and a kind, never an ISBN or an
      image — so it takes the typographic placeholder of the library, with the add button in
      its corner. Owned and missing volumes sit together in the order of the cycle, so the
      progression reads at a glance. The icon and label sizes are already fixed.
- [x] **Dashboard, show the total number of favourites.** Tapping it opens the list of every
      favourite, series included. Needs a new analytics figure and a new list screen.
- [x] **Settings screen as in Vinarium, reached from the dashboard.** Replace the "Imports"
      menu in the dashboard toolbar with a settings entry, and move the Audible connection
      into that screen. Copy every Vinarium settings menu, including the Sentry user feedback
      form (the `sendFeedback` helper exists without a screen today), except the admin
      section with the platform statistics.
- [ ] **Paywall as in Vinarium, at 1.99 a month and 17.99 a year.** Decided: an entry price
      for the first year, the one-week trial kept on the yearly plan. Rebuild the premium
      sheet on the Vinarium paywall — the allowance gauge argued from the account's own
      figures, the benefits, the two offers with the saving computed from the store's own
      prices, restore, terms and privacy. The App Store Connect app record does not exist yet
      (see [roadmap.md](roadmap.md#resolved-sign-in-with-apple)): declare the subscription
      group and both products with those prices when it is created, and keep the StoreKit
      file in lockstep. A low price is hard to raise — Apple never migrates existing
      subscribers — so this is the floor, not a trial balloon.
- [x] **Library, replace the `+` CTA** with the import entry point styled like the "add a file"
      flow of the Vinarium wine record. That flow also offers to type only a title and let the
      AI do the search. The title-only path is a new scan mutation.

## Large

- [x] **Pagination** on every list, as in Vinarium. Cursor arguments on every list query,
      client-side page accumulation, and the read-budget tests to match.
- [x] **Pre-cached screens render their data immediately** with a loader at the top while the
      fresh data loads, as in Vinarium. A persisted Apollo cache and a cache-then-network
      policy on every screen query.
- [ ] **Share sheet import.** Register Shiori as a share target so that a page shared from
      Safari or the Amazon app on iPhone offers the Shiori icon. Decided: the extension
      accepts all three payloads — the page title or selected text, which goes through the
      title lookup already built; a URL, read server-side to pull the title and the ISBN off
      the page; and a shared image, which goes through the scan. Needs an app extension
      target, an app group so the extension and the app share the session, and a
      site-by-site URL reader that will break whenever Amazon redraws its page.
- [ ] **Share a profile with friends.** A new screen lists the reader's friends; opening one
      shows their books in progress and series in progress, their favourites, and their pile.
      Decided: friendship is symmetric — accepting an invitation opens both libraries at once,
      one state to store and nothing to explain — and it is established by a shared invitation
      link, as Vinarium's household code is. The pile is the "to read" status, not a new
      ordered list. This is batch 3 of [roadmap.md](roadmap.md#batch-3--sharing) with a friend
      list on top: an invitation and acceptance flow, a friendship record, a query that reads
      another reader's books under the `hidden` rule, and it exposes books only, never the
      series catalogue.
- [ ] **Kindle import from the Amazon data export.** Decided: the reader asks Amazon for
      their data, receives a CSV, and imports it here. A one-off import, never a sync — the
      constraint recorded in [roadmap.md](roadmap.md#batch-6--kindle-import) stands, Amazon
      publishes no Kindle library API and the Audible credentials do not reach Kindle, so the
      Audible design cannot be transposed. Needs a tolerant CSV reader (Amazon renames its
      columns between exports), the same duplicate check the Audible import uses, and a screen
      that takes the file and lists what it found for the reader to tick.
