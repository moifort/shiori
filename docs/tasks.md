# Tasks

Backlog of the work agreed for the current scope, grouped by screen. A task leaves this file
when it ships; what is not yet decided stays in [roadmap.md](roadmap.md). Where a task
says "as in Vinarium", the reference implementation lives in `../vinarium` and is transposed,
not reinvented.

## Cross-cutting

- [ ] **Pagination** on every list, as in Vinarium.
- [ ] **Every CTA that runs an async call or a network request shows a loader** after the tap,
      until the call settles.
- [ ] **Adding a series updates the analytics**, including when the series is set from the
      book screen (tap on the record) rather than at scan time.
- [ ] **Lists and the dashboard analytics refresh** after a record is edited or a new book is
      added, without a manual pull.
- [ ] **Pre-cached screens render their data immediately** with a loader at the top while the
      fresh data loads, as in Vinarium.
- [ ] **Subgenre autocompletion** when the reader types a subgenre.
- [ ] **A genre or subgenre added, created or edited on a book that belongs to a series is
      applied to every book of that series.**

## Library list

- [ ] **Sort by last modification.** A series keeps its whole section together, placed by its
      most recent modification; books without a series follow the series sections. Do not
      label the standalone section.
- [ ] **Heart or stars, never both.** If the book or series is a favourite, show the heart
      only; otherwise show the star rating.
- [ ] **Series section header:** the rating or the heart is right-aligned, on the same line as
      the series title.
- [ ] **Book row:** the rating or the heart is right-aligned on the row.
- [ ] **Uniform rows.** Rework the row layout so every list shows the same data in the same
      places.
- [ ] **Replace the `+` CTA** with the import entry point styled like the "add a file" flow of
      the Vinarium wine record. That flow also offers to type only a title and let the AI do
      the search.

## Book screen

- [ ] **Cap the summary** at a word count, around 500 words.
- [ ] **Merge the Publication section into the main section.**
- [ ] **Show the volume number to the right of the cover.**
- [ ] **Show the book type as an icon** at the top right of the main section.
- [ ] **Tapping the genre section opens a modal** to change the genre.
- [ ] **Remove the "in the same series" section**, back end to front end. That list belongs to
      the series domain and must come from it.

## Import

- [ ] **Share sheet import.** Register Shiori as a share target so that a page shared from
      Safari or the Amazon app on iPhone offers the Shiori icon, and the app catalogues a book
      from the shared content.

## Dashboard

- [ ] **Show the total number of favourites.** Tapping it opens the list of every favourite,
      series included.

## Series

- [ ] **Series screen:** rework the layout and fix the icon + label bugs (size and spacing).
      Propose options that make it more readable.
- [ ] **Series list:** remove the small chevrons and put the status icon at the top right of
      each row.
