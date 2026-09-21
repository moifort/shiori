/**
 * Gives a published cover to the books that were catalogued without one, now that
 * a scan also falls back to Amazon when Open Library has nothing. Every reader's
 * books are examined; a book with an ISBN and neither a photo nor a published
 * cover goes through the same Open Library-then-Amazon lookup a scan uses.
 *
 * Runs from the Mac against production Firestore with the gcloud application
 * default credentials (`gcloud auth application-default login`). A dry run by
 * default: it lists what it would find and writes nothing. `--apply` writes
 * `publishedCoverUrl` on each book found, and marks the owner's home view stale
 * so the dashboard is rebuilt with the new covers on its next read.
 *
 * Usage: bun scripts/backfill-covers.ts [--apply]
 */

import type { Book } from '../server/domain/book/types'

process.env.GOOGLE_CLOUD_PROJECT ??= 'shiori-polyforms'

const apply = process.argv.includes('--apply')

/** One book at a time, a short pause between them, so Amazon sees a reader
 *  browsing rather than a crawler. */
const PAUSE_MS = 250

const { db } = await import('~/system/firebase')
const { publishedCoverOf } = await import('~/domain/scan/published-cover')

const snapshot = await db().collection('books').get()
const coverless = snapshot.docs
  .map((doc) => doc.data() as Book)
  .filter((book) => book.isbn13 && !book.coverPath && !book.publishedCoverUrl)

process.stdout.write(
  `${snapshot.size} books, ${coverless.length} with an ISBN and no cover` +
    `${apply ? '' : ' — dry run, nothing is written'}\n\n`,
)

const found = { openLibrary: 0, amazon: 0, none: 0 }
const owners = new Set<string>()

for (const book of coverless) {
  // biome-ignore lint/style/noNonNullAssertion: filtered on above
  const isbn13 = book.isbn13!
  const cover = await publishedCoverOf(isbn13)
  const source = !cover
    ? 'none'
    : String(cover).includes('media-amazon.com')
      ? 'amazon'
      : 'openLibrary'
  found[source] += 1
  process.stdout.write(`${source.padEnd(11)} ${isbn13}  ${book.title}\n`)

  if (cover && apply) {
    await db()
      .collection('books')
      .doc(book.id)
      .update({ publishedCoverUrl: String(cover) })
    owners.add(book.userId)
  }
  await Bun.sleep(PAUSE_MS)
}

if (apply) {
  const batch = db().batch()
  for (const userId of owners)
    batch.set(db().collection('analytics').doc(userId), { userId, stale: true }, { merge: true })
  await batch.commit()
}

process.stdout.write(
  `\nOpen Library ${found.openLibrary}, Amazon ${found.amazon}, still none ${found.none}` +
    `${apply ? `, ${owners.size} home views marked stale` : ''}\n`,
)
