import type { AuthorName, BookTitle } from '~/domain/shared/types'

/** One title read off an Amazon data export, ready to be ticked.
 *
 *  Far thinner than what an Audible import carries, and honestly so: the export
 *  is a list of purchases, not a catalogue. It names the book and who wrote it,
 *  and nothing else — no summary, no cover, no page count, no series. A book
 *  catalogued from it is a stub the reader can scan or correct afterwards.
 *
 *  Amazon's ASIN is read but not kept: nothing in Shiori would ever look at it.
 *  Only the Audible sync earns the identifier it stores, because it writes a
 *  status back night after night; a one-off import has nothing to come back to. */
export type ImportableKindleBook = {
  /** The title and first author folded together, as the duplicate check folds
   *  them. What the app ticks, rather than the title, so two different books
   *  that happen to share one are still two rows. */
  key: string
  title: BookTitle
  authors: AuthorName[]
  /** Already on the shelf under this title and author, whatever the edition.
   *  Shown ticked off and untappable, as the Audible picker shows them: hidden,
   *  they would read as titles the import lost. */
  alreadyInLibrary: boolean
}

/** What a file that is not an Amazon export answers with. The reader picked the
 *  wrong CSV — an order history, a Kindle reading session — and must be told
 *  that rather than shown an empty list they would read as "nothing to import". */
export type UnreadableExport = 'no-title-column'
