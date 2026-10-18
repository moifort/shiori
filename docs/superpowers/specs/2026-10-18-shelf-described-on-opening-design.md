# Shelf books described on first opening — design

## Problem

On 2026-10-17 two shelf photos of about twenty books each cost €6.59: 535 billed Google searches,
the month's 5,000 free ones long spent. Every ticked book ran three grounded Gemini calls before it
was saved — its own description (half the searches), its author's page and its saga's catalogue
(the other half) — about €0.15 a book. Most of those books are never opened: a reader importing a
shelf wants it catalogued, not read about twenty times over.

## Decision

A book ticked on a shelf photo is saved at once from what its spine printed, with no Gemini call,
and described the first time its page is opened. The author's page and the saga's catalogue are
built when they are opened, as they already are after an Audible import.

- **The scan is spent on adding**, as before: one per book, so the allowance means what it meant.
  Opening the page afterwards costs the reader nothing, even with the allowance used up — the scan
  paid for it.
- **The cover is looked up without Gemini.** Open Library's search, by title, first author and the
  printed volume number, in the edition's language, names the work's ISBNs; the first three in the
  edition's ISBN registration group (978-2 / 979-10 for French) go through the scan's own cover
  chain, Amazon then Open Library. An ISBN from another language is never used: a wrong edition's
  cover is worse than the placeholder. When the narrow search finds nothing, a broader one
  (`q=title:(…) author:(…)`) is asked once. The ISBN is not stored — it may be another edition's.
- **The first opening rewrites the record** as a refresh does (`refreshedFacts`): summary, genre,
  subgenres, page count, first publication, the ISBN, and the published cover sought again by that
  exact ISBN, which replaces the provisional one when found.

Trial on 25 books (2026-10-18): 16 right covers, 2 wrong (a derivative of *Le Petit Prince*, volume
2 of *Le Problème à trois corps*), 7 placeholders — chiefly translated novels and manga volume 1s.
Without the volume number and the language filter, 4 in 20 were wrong (Naruto volume 33 for the
saga, Blacksad in English).

## Cost

| | Before | After |
|---|---|---|
| Adding a book from a shelf | 3 grounded calls ≈ 12 billed searches ≈ €0.15 | 0 Gemini calls, 1–3 free HTTP requests |
| Opening its page the first time | 0 | 1 grounded call ≈ 4 billed searches ≈ €0.05 |
| Its author's / saga's page, first opened | 0 (built on adding) | 1 grounded call each, as today for an Audible import; shared, so paid once for everyone |
| Shelf of 20, 5 pages opened | ≈ €3 | ≈ €0.25–0.50 |

The release watch and Découvrir are unchanged.

## Server

- `Book.awaitingDescription` (`true` or absent): what a spine showed and nothing more. New
  optional field, no migration. A shelf book joining a record the reader already keeps on another
  medium (`mergedCopies`) is flagged only if that record was too. A reader's refresh clears it.
- `addDetectedBook(book: DetectedBookInput!): Book!` — refused with `QUOTA_EXHAUSTED` once the
  allowance is used up; saves the book through `BookUseCase.add` (so a paper copy joins its Kindle
  copy), flagged, with the shelf cover; spends one scan once saved. `DetectedBookInput` gains the
  printed `seriesName` and `volume`, from which the saga is keyed as a scan keys it.
- `describeBook(id: BookId!): Book!` — on a flagged book, the grounded lookup a refresh runs
  (`lookUpVolume`'s hints for a saga volume), unmetered and not quota-gated, then the flag is
  cleared. On a book not flagged, the book as it is, with no model call: the mutation can never be
  a free refresh. Fails with `SCAN_FAILED` and leaves the flag, so the next opening asks again.
- `describeDetectedBook` no longer builds the author's page and the saga's catalogue, which halves
  the cost for builds already installed. The app stops calling it, so it is deprecated in favour of
  `addDetectedBook`.

## iOS

- `ShelfImportViewModel` adds each ticked book with one `addDetectedBook` call instead of
  `describeDetectedBook` then `addBook`: faster, since nothing waits on Gemini.
- `BookViewModel` asks `describeBook` once the page has loaded a flagged book; the page shows what
  it has meanwhile, with "Fiche en cours de complétion…" where the summary goes. A failure leaves
  the page as it is, silently: the next opening tries again.

## Testing

- `*.unit.test.ts` — the ISBN language filter; `mergedCopies` and the flag.
- `*.int.test.ts` — `addFromShelf` spends one scan, saves flagged, refuses an exhausted allowance;
  `describe` rewrites and clears the flag without spending, and leaves an unflagged book untouched
  with no model call.
- `*.feat.test.ts` — both mutations against the built schema.
