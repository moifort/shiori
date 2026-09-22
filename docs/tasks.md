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
- [x] **Book screen, header and menu touch-ups.** Drop the icon in front of "Lu par"; show
      the duration as a pill at the top right of the main section, beside the format icon;
      give the genre its own icon beside its name and an icon to each subgenre pill; and
      rename "Retirer de ma bibliothèque" to "Supprimer" in the CTA menu.
- [x] **Dashboard, remember the reading chart metric across launches.** The segmented picker
      of the reading chart widget is a plain `@State` today, so it resets to pages on every
      start. Persist the choice (`@AppStorage`) and restore it on launch.
- [x] **Dashboard, hide the pages when the library holds no printed book.** The mirror of the
      listening hours rule: a library of audiobooks only drops the "Pages" segment of the
      reading chart widget, and a persisted choice of that metric falls back to hours.
- [x] **Dashboard, tapping the average rating tile opens the library on its favourites
      filter.** Switches to the Library tab with the favourites view selected.
- [x] **Dashboard, remove the favourites tile.** The average rating tile now leads to the
      favourites; check whether `FavoritesView` still has an entry point once the tile is
      gone, and delete it if not.
- [x] **Dashboard, tapping the genres widget opens the library on its genre view.** Switches
      to the Library tab with the genre view selected.

- [x] **Audible badge on the cover.** An audiobook carries the Audible logo as a pill at
      the top right of its cover, in every list and on the book screen alike.
      Built: an orange headphones pill on every audiobook's cover, rather than the Audible
      logo, which the app would have to ship as a trademark asset.
- [x] **Book screen, the reading status at the top right of the main section,** where the
      format icon sits today. The format moves to the cover badge above, so the corner says
      "en cours", "à lire" and so on instead.
      Built on the library row, where the headphones glyph was: the book screen keeps its
      status picker, and shows a pill in that corner only for a dropped book.
- [x] **Menu icons at the right size and spacing, app-wide.** The icons in the dropdown
      menus are sized and spaced inconsistently; go through every `Menu` of the app and
      align them on one size and one gap.
- [x] **Multiline fields, the icon aligned on the first line of text.** The subgenre field's
      icon is centred on the whole field; it should sit level with the top line. Same fix
      for every multiline field of the app.
- [x] **Book edit screen, edit the narrators.** `BookEdit` and the `editBook` input already
      accept them; only the form is missing.
- [x] **Library list, show the date added** beside the started and finished dates on a row.
      Built on the book screen's reading section, beside the started and finished dates.
- [x] **Library, genre view headings in the app's language.** The section titles of the
      genre view must read the genre's localized name, not its raw value.
      Built: "Fantasy" now reads "Fantastique".

- [ ] **Dashboard, bigger icons on the favourites and dropped tiles.** The heart and the
      thumbs-down of the two small boxes are drawn at `.subheadline` in a 22 pt frame, small
      beside the count and its label; enlarge them (around `.title2`) so they balance the
      two lines of text beside them (`StatTilesRow.smallTile`).

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
- [x] **Series screen, rework it around a shelf of covers.** Decided: the volumes become a
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
- [x] **Paywall as in Vinarium, at 1.99 a month and 17.99 a year.** The sheet itself was
      already the Vinarium paywall, transposed with Shiori's own copy: the allowance gauge
      argued from the account's own figures, the benefits, the two offers with the saving
      computed from the store's prices, restore, terms and privacy. Only the prices moved.
      The yearly keeps the one-week trial and now saves 25 % against twelve months, which the
      badge computes on its own. **Still to do outside this repository:** declare the
      subscription group and both products at those prices on the App Store Connect record,
      which does not exist yet (see
      [roadmap.md](roadmap.md#resolved-sign-in-with-apple)). A low price is hard to raise —
      Apple never migrates existing subscribers — so this is the floor, not a trial balloon.
- [x] **Library, replace the `+` CTA** with the import entry point styled like the "add a file"
      flow of the Vinarium wine record. That flow also offers to type only a title and let the
      AI do the search. The title-only path is a new scan mutation.
- [x] **Audible import, pick the right genre.** Checked against the public catalogue API
      (`api.audible.fr/1.0/catalog/categories/{id}`) and forty real titles, the genre an import
      lands in is wrong for three reasons. **The ladder order decides:** `genreFrom` takes the
      first ladder Amazon returns, and that is often the catch-all "Littérature, romans et
      fiction", so Dune, Fondation, Le problème à trois corps and Le Dernier vœu all come out
      `literary-fiction`. Have every ladder vote instead, with the generic racks (literary
      fiction, classics, contemporary, the joint SF-fantasy rack) answering only when nothing
      else does. **Whole subtrees are unmapped:** Harry Potter gets no genre at all, since
      "Jeunesse > Science-fiction et fantasy > Fantasy et magie" only resolves its root; also
      missing are "Fiction criminelle", "Policier > Polars / Cozy", "Sorcellerie et épées",
      and the SF and fantasy racks under "Adolescents". **The `com` ids in `audible-api-ts`
      are nearly all wrong:** they are shifted, so `thriller` points at Classics and
      `horror` at Computers & Technology. Only the `fr` ids are correct. The new ids and the
      `com` fix belong in `../audible-api-ts`, with a test that checks the table against the
      live API. The unit tests could not catch any of this because they build their ladders
      from `resolveGenreId`. Books already imported keep their wrong genre, so they need
      re-mapping through a migration or a fresh import.

- [x] **Book edit screen, a running time instead of pages for an audiobook.** An audiobook
      offers no page count field but a duration field, typed as hours and minutes ("14h30").
      `durationMinutes` is not part of `BookEdit` nor of the `editBook` input yet.
- [x] **Subgenres in title case, their own capitals kept.** Every word of a subgenre starts
      with a capital, and a capital already inside a word stays: "LitRPG" stays "LitRPG",
      never "Litrpg". Normalized in the `Subgenre` constructor so the scan, the import and the
      form agree; existing records need a migration, since the autocompletion would otherwise
      offer both spellings.
- [x] **Library views cached, with the small loader on top.** The favourites and genre views,
      and every status filter, render last visit's rows at once with the refresh spinner
      leading the list, as the default view does, rather than an empty list reloading on
      every switch. Today only the default view has a `SnapshotCache`.
- [x] **A "dropped" reading status.** A new state in the book screen's status menu for a
      book the reader stopped because they could not go on or did not like it. The default
      library view gives it its own section, last. A new enum value needs no migration, but
      the analytics (pile, finishes) and every `match().exhaustive()` over the status must
      decide what a dropped book counts as.
- [x] **Dashboard, two small tiles: favourites and dropped.** One counts the favourites, the
      other the books the reader stopped because they did not like them — the "dropped"
      status above, which this depends on. The server still serves `favoriteCount`; the
      dropped count is a new analytics figure. Each tile opens the library on the matching
      view.

- [x] **Series tab, the library's filters.** The same toolbar as the Library tab: switch
      between everything, by genre and the favourites, and narrow any of them to one reading
      status. The tab is sectioned by genre today with no way to change it, so the series
      query needs the arrangement, favourite and status arguments `libraryPage` already has.

- [x] **Series tab, the missing volumes in each row's strip.** The strip shows only the
      volumes the reader owns: `FollowedSeries.volumes` is a list of their own `Book`s. The
      volumes of the cycle they do not have should sit in it too, in cycle order, drawn with
      the typographic placeholder the series screen uses for them. That reads the catalogue
      for every row of the page, which the denormalized layout was built to avoid: add a
      per-request loader for `series/{seriesKey}` before shipping, and a read-budget test.
- [x] **Series catalogue, no volume listed twice.** The Blood Song screen shows Tome 1 and
      Tome 2 twice each, with the same book behind both rows. The grounded catalogue call can
      return one volume per edition it finds, and `catalogueSeries` stores the list as the
      model answered it, with no deduplication between there and the screen. Deduplicate while
      parsing: one main volume per number, one unnumbered entry per kind and slugified title.
      No migration: the stored catalogues are cleaned by hand in the database.
- [x] **Onboarding offers the Audible import.** A new reader lands on an empty library, while
      an Audible listener already has one waiting. Add a step after the first name that offers
      to connect Audible, with a plain way to skip it. It reuses `AudibleImportView` as it
      stands rather than a second copy of the flow. The step comes after
      `completeOnboarding`, so the welcome scans are granted even if the reader abandons
      the Amazon sign-in. Skipping, or closing the import, leads into the app as today.
- [x] **One empty state for every list, on the dashboard's model.** The dashboard's empty
      library page — icon, title, one sentence, a prominent "Scanner un livre" button — is
      the reference. Every list gets the same shape. Today each draws its own
      `ContentUnavailableView` with its own wording, some with an action, some without: the
      library, a narrowed library (favourites, one status), the Series tab, a friend's
      profile. Extract one shared component in `Shared/Components` that takes the icon, title,
      sentence and optional action, and use it everywhere. Error states ("… indisponible",
      "Réessayer") get the same treatment, as a second variant of the same component.
- [x] **Dashboard drawn even when the library is empty.** Instead of the full-page empty
      state, show the dashboard itself with every card in a designed empty state: a muted
      placeholder of what the card will hold (grey bars for the reading chart, blank cover
      tiles for the shelves, an empty progress ring for the series) under a short line that
      says what fills it. `WidgetEmptyMessage` is the starting point, but today it is plain
      grey text. The scan call to action stays visible at the top, since that is the one
      thing the reader can do from here. `libraryIsEmpty` stops choosing between two pages.

- [x] **Series tab, every volume's cover in the strip, as on the series screen.** The strip
      shows the missing volumes only when the saga has a catalogue, and even then leaves out
      the announced volumes and the related works. It should show every volume the series
      screen lists — the spine, announced volumes included, then the prequels, novellas and
      companions — each missing one as the same dimmed placeholder. A saga never opened has
      no catalogue yet, since the screen is what builds it: decide whether the tab triggers
      that build, or keeps showing only the owned volumes until then.
      Built: the strip reads the spine and the related works; an announced volume is fainter
      and carries a clock where an owned one pins its status. A saga never opened keeps
      showing its owned volumes only: building catalogues from the tab would pay one AI call
      per row just for scrolling past it.

- [ ] **Library and Series tabs, drop the "by genre" sections.** Remove the arrangement from
      both toolbars, which leaves everything, the favourites and the status filters. The
      `by-genre` value of `LibraryArrangement` and the arrangement argument go with it if
      nothing else reads them. The dashboard's genres widget opens the library on that view
      today: decide where a tap on it leads instead, or make it inert.
- [ ] **Library and Series tabs, sorted by date under "Month Year" headings, as in
      Vinarium.** A book is placed by its finish date, else its start date, else the date it
      was added, newest first, and the list is cut into sections titled with the month and
      year of that date in the app's language ("septembre 2026"), with Vinarium's
      `MMMM yyyy` formatter. The Series tab applies the same rule to each saga, dated by its
      most recent volume. Replaces the ordering by last modification, which grouped a saga's
      volumes into one section: decide whether a saga still keeps its volumes together in
      the Library tab, and under which month, or whether each volume falls under its own.
      Changes the `library` and series queries' ordering and their cursors.

## Large

- [ ] **Subgenres and tags in the app's language, the scan's included.** A subgenre is free
      text stored as the source wrote it, so one library mixes languages: the Audible import
      files an audience as "Young Adult", the scan prompt's examples are French whatever the
      reader's language, and switching the app to English leaves every stored subgenre in
      French. Every subgenre and tag the app shows, and every one the scan or the import
      writes, must read in the app's language. Probably means turning subgenres into a
      closed vocabulary of keys localized in `Localizable.xcstrings`, as the genres are, with
      the scan and the import mapping onto those keys and a free-text fallback decided for
      what falls outside it. Existing records need a migration onto the keys, and the
      autocompletion and the series fan-out follow.

- [x] **Pagination** on every list, as in Vinarium. Cursor arguments on every list query,
      client-side page accumulation, and the read-budget tests to match.
- [x] **Pre-cached screens render their data immediately** with a loader at the top while the
      fresh data loads, as in Vinarium. A persisted Apollo cache and a cache-then-network
      policy on every screen query.
- [x] **Share sheet import.** Register Shiori as a share target so that a page shared from
      Safari or the Amazon app on iPhone offers the Shiori icon. Decided: the extension
      accepts all three payloads — the page title or selected text, which goes through the
      title lookup already built; a URL, read server-side to pull the title and the ISBN off
      the page; and a shared image, which goes through the scan. Needs an app extension
      target, an app group so the extension and the app share the session, and a
      site-by-site URL reader that will break whenever Amazon redraws its page.
      Built: a `ShioriShare` app-extension target writes what was shared into the
      `group.com.polyforms.shiori.app` container, and the app picks it up on every return to
      the front. The extension carries no session of its own. The page reader is not
      site-by-site: only the `<title>` is read and the shop's own name stripped off it, which
      survives a redesign. **Apple Developer portal work is outstanding** — an App ID for
      `com.polyforms.shiori.app.share`, the App Groups capability on both App IDs, and a
      "Shiori Share App Store" provisioning profile, stored as the
      `IOS_SHARE_PROVISION_PROFILE` secret the release workflow now expects.
- [x] **An invitation link opens the app, not a web page.** Tapping an invitation on an
      iPhone with Shiori installed opens the app on the invitation itself, with one tap to
      accept. A universal link: the API serves `/.well-known/apple-app-site-association`
      scoped to `/invite/*`, the app carries the matching `applinks:` entitlement, and
      `AuthRoot` catches the link and holds the code until the reader is signed in and past
      onboarding. The web page stays for everybody else — no app, a laptop, an in-app browser
      that swallowed the universal link — and offers `shiori://invite/<CODE>` to reopen the
      app, since a universal link cannot re-trigger from the page it already landed on.
      Accepting is never automatic: the link comes from somewhere the reader does not control.
      **Outstanding**: the Associated Domains capability on the App ID, and a rebuilt
      "Shiori App Store" profile carrying it.
- [x] **Share a profile with friends.** A new screen lists the reader's friends; opening one
      shows their books in progress and series in progress, their favourites, and their pile.
      Decided: friendship is symmetric — accepting an invitation opens both libraries at once,
      one state to store and nothing to explain — and it is established by a shared invitation
      link, as Vinarium's household code is. The pile is the "to read" status, not a new
      ordered list. This is batch 3 of [roadmap.md](roadmap.md#batch-3--sharing) with a friend
      list on top: an invitation and acceptance flow, a friendship record, a query that reads
      another reader's books under the `hidden` rule, and it exposes books only, never the
      series catalogue.
- [ ] **A TestFlight build from CI, without cutting a release.** Today `release-ios.yml`
      only fires on an `ios-v*` tag, so testing a change on a real phone means tagging a
      release that is not one. Wanted: a workflow that archives, uploads and distributes to
      an internal TestFlight group on demand — `workflow_dispatch`, and optionally every push
      to `main` — with the build number taken from the run number or the commit count so two
      uploads never collide, and the release notes taken from the commit subject. It shares
      every signing step with `release-ios.yml`, so the two should be one reusable workflow
      called twice rather than a copy: the difference is the trigger, the build number and
      whether App Store Connect is asked to submit for review. Needs an internal testing
      group in App Store Connect, which does not exist yet because the app has no record
      there.

- [x] **Kindle import from the Amazon data export.** Decided: the reader asks Amazon for
      their data, receives a CSV, and imports it here. A one-off import, never a sync — the
      constraint recorded in [roadmap.md](roadmap.md#batch-6--kindle-import) stands, Amazon
      publishes no Kindle library API and the Audible credentials do not reach Kindle, so the
      Audible design cannot be transposed. Needs a tolerant CSV reader (Amazon renames its
      columns between exports), the same duplicate check the Audible import uses, and a screen
      that takes the file and lists what it found for the reader to tick.

- [x] **Series screen, rework it on the book screen's model.**
      - The progress label on one line, "0/3" with no spaces, same size and weight as today.
      - The genre and subgenres merge into the main section, shown and edited exactly as on
        the book screen; so does the rating.
      - "Commencée le", "ajoutée le" and "terminée le" as date fields, derived from the
        dates of its books.
      - The volume list drawn with the rows and style of the library list, each row opening
        the reader's own book.
      - Delete a series, with an alert that says every book of the series is deleted with it.
