import type { DocumentData, DocumentReference, WriteBatch } from 'firebase-admin/firestore'
import { chunk, groupBy } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations; a merge writes the record
// kept, deletes the one absorbed and repoints its awaited editions.
const BATCH_SIZE = 100

/** Paper or screen is where a book is held, not what it is.
 *
 *  Every book takes `media`: `ebook` becomes a `book` held `digital`, every
 *  other read book is held `print`, a recording is held on neither. A book
 *  linked to its Kindle title keeps the cover it was imported with as its
 *  Kindle cover, which is now drawn before any other.
 *
 *  Then each reader's paper and screen copies of one book become one record:
 *  same title and first author, same volume and language wherever both say,
 *  one held on a medium the other lacks. The earliest added is kept and fills
 *  its blanks from the other; where both said something of the reading, the
 *  furthest along wins — status, earliest start, latest finish, higher rating,
 *  either heart, both notes. The other is deleted, and the awaited editions
 *  that named it name the record kept.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const paperAndScreenAreOneBook: Migration = {
  version: MigrationVersion(14),
  name: MigrationName('paper-and-screen-are-one-book'),
  migrate: async ({ db }) => {
    const books = (await db.collection('books').get()).docs.map((doc) => ({
      ref: doc.ref,
      data: held(doc.data()),
    }))

    const merges: Merge[] = []
    for (const library of Object.values(groupBy(books, (book) => book.data.userId)))
      merges.push(...mergesIn(library))
    const absorbed = new Set(merges.map((merge) => merge.absorbed.ref.id))
    const kept = new Set(merges.map((merge) => merge.kept.ref.id))
    const rewritten = books.filter((book) => !absorbed.has(book.ref.id) && !kept.has(book.ref.id))

    for (const slice of chunk(rewritten, BATCH_SIZE * 4)) {
      const batch: WriteBatch = db.batch()
      for (const book of slice) batch.set(book.ref, book.data)
      await batch.commit()
    }

    const awaited = (await db.collection('awaited-editions').get()).docs
    for (const slice of chunk(merges, BATCH_SIZE)) {
      const batch: WriteBatch = db.batch()
      for (const merge of slice) {
        // Its final state, whichever of its merges writes it.
        batch.set(merge.kept.ref, merge.kept.data)
        batch.delete(merge.absorbed.ref)
        for (const edition of awaited) {
          const source = edition.data().source
          if (source?.bookId === merge.absorbed.ref.id && source?.ownerId === merge.userId)
            batch.update(edition.ref, { source: { ...source, bookId: merge.kept.ref.id } })
        }
      }
      await batch.commit()
    }
    return { ok: true, transformed: rewritten.length + merges.length }
  },
}

type Stored = { ref: DocumentReference; data: DocumentData }
type Merge = { userId: string; kept: Stored; absorbed: Stored }

/** A stored book as it is held now: `ebook` folded into `book` on a screen. */
const held = (book: DocumentData): DocumentData => {
  const ebook = book.format === 'ebook'
  const format = ebook ? 'book' : (book.format ?? 'book')
  const media =
    format === 'audiobook'
      ? []
      : ebook
        ? ['digital']
        : Array.isArray(book.media) && book.media.length > 0
          ? book.media
          : ['print']
  const kindleCoverUrl =
    book.kindleCoverUrl ?? (book.kindleAsin ? book.publishedCoverUrl : undefined)
  return withoutAbsent({ ...book, format, media, kindleCoverUrl })
}

/** One reader's merges, earliest copy kept. A merged record keeps absorbing:
 *  a paperback, then its Kindle copy, then nothing more. */
const mergesIn = (library: Stored[]): Merge[] => {
  const merges: Merge[] = []
  const records: Stored[] = []
  for (const book of library.toSorted(
    (a, b) => millisOf(a.data.addedAt) - millisOf(b.data.addedAt),
  )) {
    const into = records.find((record) => joins(record.data, book.data))
    if (!into) {
      records.push(book)
      continue
    }
    into.data = merged(into.data, book.data)
    merges.push({ userId: into.data.userId, kept: into, absorbed: book })
  }
  return merges
}

const joins = (kept: DocumentData, other: DocumentData): boolean =>
  kept.format !== 'audiobook' &&
  other.format !== 'audiobook' &&
  shelfKeyOf(kept) === shelfKeyOf(other) &&
  agrees(kept.series?.volume, other.series?.volume) &&
  agrees(kept.language, other.language) &&
  other.media.some((medium: string) => !kept.media.includes(medium))

const shelfKeyOf = (book: DocumentData) =>
  `${slugify(book.title ?? '')}--${slugify(book.authors?.[0] ?? '')}`

const agrees = (kept: unknown, other: unknown) =>
  kept === undefined || other === undefined || kept === other

const PROGRESS: Record<string, number> = { 'to-read': 0, reading: 1, dropped: 2, read: 3 }
const MEDIA = ['print', 'digital']

/** The two copies as one record: `kept` names it and states what it states,
 *  `other` fills its blanks; the reading keeps the furthest of the two. */
const merged = (kept: DocumentData, other: DocumentData): DocumentData => {
  const format = kept.format === 'book' ? other.format : kept.format
  const status =
    (PROGRESS[other.status] ?? 0) > (PROGRESS[kept.status] ?? 0) ? other.status : kept.status
  const hearted = [kept, other].filter((copy) => copy.favorite === true)
  const notes = [kept.note, other.note].filter((note) => typeof note === 'string')
  const ratings = [kept.rating, other.rating].filter((rating) => typeof rating === 'number')
  const finishedAt = latest(
    [kept, other].filter((copy) => copy.status === 'read').map((copy) => copy.finishedAt),
  )
  const startedAt = status === 'to-read' ? undefined : earliest([kept.startedAt, other.startedAt])
  const addedAt = earliest([kept.addedAt, other.addedAt])
  return withoutAbsent({
    ...other,
    ...withoutAbsent(kept),
    format,
    media: MEDIA.filter((medium) => kept.media.includes(medium) || other.media.includes(medium)),
    authors: kept.authors?.length > 0 ? kept.authors : other.authors,
    subgenres: kept.subgenres?.length > 0 ? kept.subgenres : other.subgenres,
    narrators: kept.narrators?.length > 0 ? kept.narrators : other.narrators,
    status,
    rating: ratings.length > 0 ? Math.max(...ratings) : undefined,
    favorite: hearted.length > 0 ? true : undefined,
    favoritedAt: earliest(hearted.map((copy) => copy.favoritedAt)),
    note: notes.length > 0 ? notes.join('\n\n').slice(0, 10000) : undefined,
    hidden: kept.hidden === true || other.hidden === true,
    addedAt,
    startedAt,
    finishedAt,
    statusChangedAt: latest([kept.statusChangedAt, other.statusChangedAt]),
    shelvedAt: finishedAt ?? startedAt ?? addedAt,
  })
}

/** A stored date's instant, whether the store hands back a `Timestamp` or a
 *  `Date`. */
const millisOf = (value: unknown): number => {
  if (value instanceof Date) return value.getTime()
  const timestamp = value as { toMillis?: () => number } | undefined
  return timestamp?.toMillis?.() ?? 0
}

const earliest = (values: unknown[]) =>
  values.filter((value) => value != null).toSorted((a, b) => millisOf(a) - millisOf(b))[0]

const latest = (values: unknown[]) =>
  values.filter((value) => value != null).toSorted((a, b) => millisOf(b) - millisOf(a))[0]

const withoutAbsent = (record: DocumentData): DocumentData =>
  Object.fromEntries(Object.entries(record).filter(([, value]) => value !== undefined))
