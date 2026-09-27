# Shelf import — design

## Problem

A reader catalogues a library in bursts, and today every book is one photo, one wait, one review
screen. Emptying a shelf of thirty books is thirty round trips. The books are already lined up:
spines on a shelf, or covers laid out on the floor. One photo holds them all.

## Decision

One photo, many books, reviewed as a checklist. Premium only.

The photo is read once, without web search, for what each book shows — title, authors, volume —
and where it sits in the frame. The reader ticks the books to keep; each ticked book then goes
through the enrichment a single scan already uses, and is saved with the existing `addBook`. The
reader pays for what they keep, not for what the camera saw.

Out of scope: several photos in one import, detecting a multi-book photo on its own in the recent
photos strip, and an import that survives the app being killed.

## Flow

1. **Entry.** The add sheet gains a "Plusieurs livres" tile beside the camera, with a Premium
   badge. A free reader who taps it gets the `PremiumSheet`. From it the reader shoots, or picks
   one photo from the library.
2. **Viewfinder.** `CameraView` with a "Un livre / Plusieurs" switch, a wider frame and the hint
   "Tranches bien lisibles, ou couvertures posées à plat".
3. **Detection.** The photo is shown while it is read; when the answer arrives, a frame lights up
   on each book found.
4. **Checklist.** The photo on top, the books below in reading order (left to right, top to
   bottom). Each row shows the book cropped out of the reader's photo, its title, authors and
   volume.
   - A book the reader already owns comes **unticked**, badged "Déjà chez vous".
   - A book whose title could not be read comes **unticked**, labelled "Tranche illisible";
     tapping it opens the correction sheet.
   - Everything else comes ticked. Tapping a row highlights its frame on the photo.
   - The button reads "Ajouter N livres · N scans", and turns into the paywall when the month's
     allowance cannot cover N.
5. **Correction.** A sheet with the crop enlarged and two fields, title and authors. Correcting
   an unreadable book ticks it.
6. **Adding.** One row per ticked book: waiting, in progress, added, failed with "Réessayer".
   Three books at a time. The sheet can be closed: the work goes on while the app lives, and each
   book appears in the library as it is saved. Killing the app abandons the books not yet saved;
   the reader imports the photo again, and the ones already added come back as "Déjà chez vous".

## Server

### `detectBooks(imageBase64: String!): [DetectedBook!]!`

A new mutation in `server/domain/scan/`, through a `ScanUseCase.detectBooks` entry point.

- **Premium only.** A free account is refused with `PREMIUM_REQUIRED` before the model is called.
- **Spends nothing**, like `searchTitle`, but is refused with `QUOTA_EXHAUSTED` once the
  allowance is used up, since every lookup that follows would be.
- **One model call, no web search.** A `shelfPrompt` in `prompts.ts`, in the spirit of
  `visionPrompt`: only what is printed, nothing inferred, `recognized`-style honesty for a spine
  the model cannot read. It covers both layouts, spines and covers, without asking the reader
  which.
- **At most 30 books.** Past that the answer is truncated to the 30 read first. The hint on the
  viewfinder says so.
- **Not cached.** Detection spends nothing for the reader, and a photo of a shelf is rarely sent
  twice.
- AI usage is recorded for the admin screen, as for a title search.
- Same `IMAGE_TOO_LARGE` limit as `scanBook`.

`DetectedBook`:

| Field | Type | Meaning |
|---|---|---|
| `title` | `String` | As printed; `null` when unreadable |
| `authors` | `[String!]!` | As printed, translators excluded |
| `publisher` | `String` | When the logo or name is legible |
| `language` | `BookLanguage` | Of this edition, when the text says |
| `format` | `BookFormat` | Same rules as the cover scan |
| `seriesName`, `volumeNumber` | | Only when printed |
| `box` | `DetectedBox!` | `x`, `y`, `width`, `height`, each in `0...1` of the photo |
| `owned` | `Boolean!` | The reader already has it, by `shelfKeyOf` |

`owned` is answered from `BookQuery.shelfKeys(userId)`, one query for the whole photo. The box
comes from Gemini's `box_2d` (`[ymin, xmin, ymax, xmax]` on a 0–1000 grid), converted once in the
command so the app never sees the model's convention.

### Enriching a ticked book

`describeDetectedBook(book: DetectedBookInput!): ScanResult`, a thin mutation over the existing
`ScanUseCase.lookUpEdition`: the same web-grounded enrichment, published cover and series
catalogue as a single scan, metered the same way — one scan, only on success. The input carries
what the checklist holds, corrections included. The app then saves with `addBook`, unchanged, so
a book imported from a shelf is indistinguishable from one scanned alone.

Two calls per book rather than one "describe and save" mutation: saving keeps a single path, and
a failed description leaves nothing half-written.

## iOS

In `Features/Scan/`, beside the single scan rather than inside its state machine:

- `ShelfImportViewModel` — steps camera, detecting, checklist, adding; owns the photo, the
  detected books, the ticks and the per-book progress. Adding runs in a task group capped at 3,
  held by the view model so closing the sheet does not cancel it.
- Pages `ShelfDetectingPage`, `ShelfChecklistPage`, `ShelfAddingPage`, and the
  `DetectedBookSheet` correction sheet.
- The crop is cut on device from the full-resolution photo with the returned box; it is never
  uploaded.
- The photo is sent at 2000 px on the long side, not 1000: a spine's title is a few pixels tall.
  JPEG 0.7 keeps it well under the 10 MB limit.
- `ShelfAPI` for `detectBooks` and `describeDetectedBook`; saving goes through `BookAPI.add`.
- Errors: `PREMIUM_REQUIRED` and `QUOTA_EXHAUSTED` open the `PremiumSheet`; a detection that
  finds nothing shows the no-result page with a retake; a failed detection keeps the photo for a
  retry, as the single scan does.

## Testing

- `*.unit.test.ts` — the `box_2d` conversion, reading order, the 30-book cap, the premium gate.
- `*.int.test.ts` — `detectBooks` against the fake Firestore with Gemini mocked: `owned` from one
  `shelfKeys` query (read budget asserted), nothing spent, refused for free and exhausted
  accounts. `describeDetectedBook` spends exactly one scan on success and none on failure.
- `*.feat.test.ts` — both mutations against the built schema, their error codes.
- Before release, the prompt is tried on real photos — a shelf of spines, a floor of covers,
  mixed formats, a partly unreadable shelf — to decide whether `gemini-3.5-flash-lite` reads
  spines well enough or detection needs the larger model.
