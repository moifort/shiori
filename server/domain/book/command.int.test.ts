import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
const { StarRating, ReadingNote, Publisher, PageCount, RecommendationComment } = await import(
  '~/domain/book/primitives'
)
const { PersonName } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-09-14T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const add = (title: string, status?: 'to-read' | 'reading' | 'read') =>
  BookCommand.add(reader, { title: BookTitle(title), status }, NOW)

describe('cataloguing a book', () => {
  test('lands it on the pile when no status is given', async () => {
    const book = await add('Le Nom du vent')

    expect(book.status).toBe('to-read')
    expect(book.hidden).toBe(false)
    expect(book.startedAt).toBeUndefined()
  })

  test('catalogues it as a book when no format is given', async () => {
    const book = await add('Le Nom du vent')

    expect(book.format).toBe('book')
    expect(fake.data('books', book.id)?.format).toBe('book')
  })

  test('lets the reader correct the format afterwards', async () => {
    const book = await BookCommand.add(reader, { title: BookTitle('Blacksad') }, NOW)

    const edited = await BookCommand.edit(reader, book.id, { format: 'bande-dessinee' })

    expect(edited).toMatchObject({ format: 'bande-dessinee' })
  })

  // A correction can remove a fact the scan invented, not only replace it.
  test('drops a field the reader cleared, and keeps the rest', async () => {
    const book = await BookCommand.add(
      reader,
      { title: BookTitle('Blacksad'), publisher: Publisher('Dargaud'), pageCount: PageCount(56) },
      NOW,
    )

    const edited = await BookCommand.edit(reader, book.id, { publisher: undefined })

    if (typeof edited === 'string') throw new Error('unreachable')
    expect(edited.publisher).toBeUndefined()
    expect(Number(edited.pageCount)).toBe(56)
    expect(Object.hasOwn(fake.data('books', book.id) as object, 'publisher')).toBe(false)
  })

  // An import knows when the reader got the book, and the library is cut into
  // months on that date: a title bought in 2019 must not land on import night.
  test('lands on the day the caller says it was added, and stamps the status then', async () => {
    const PAST = new Date('2019-06-01T00:00:00.000Z')
    const book = await BookCommand.add(reader, { title: BookTitle('Dune'), addedAt: PAST }, NOW)

    expect(book.addedAt).toEqual(PAST)
    expect(book.statusChangedAt).toEqual(PAST)
    expect(book.updatedAt).toEqual(NOW)
  })

  // Nobody knows when the reading began; the day the book arrived is the honest
  // lower bound, and the only one that keeps it out of the current month.
  test('starts a book already being read on the day it was added, for want of better', async () => {
    const PAST = new Date('2019-06-01T00:00:00.000Z')
    const book = await BookCommand.add(
      reader,
      { title: BookTitle('Dune'), status: 'reading', addedAt: PAST },
      NOW,
    )

    expect(book.startedAt).toEqual(PAST)
    expect(book.statusChangedAt).toEqual(PAST)
  })

  test('stamps a start when it is catalogued as already being read', async () => {
    const book = await add('Le Nom du vent', 'reading')

    expect(book.startedAt).toEqual(NOW)
    expect(book.finishedAt).toBeUndefined()
  })

  // Saying when a book was finished is saying when it moved to the read shelf,
  // so the library order follows the corrected date.
  test('files a read book on the finish date the reader corrected', async () => {
    const MARCH = new Date('2026-03-12T12:00:00.000Z')
    const book = await add('Le Nom du vent')
    await BookCommand.setStatus(reader, book.id, 'read', NOW)

    const FEBRUARY = new Date('2026-02-20T12:00:00.000Z')
    const edited = await BookCommand.edit(
      reader,
      book.id,
      { startedAt: FEBRUARY, finishedAt: MARCH },
      NOW,
    )
    if (typeof edited === 'string') throw new Error('unreachable')
    expect(edited.finishedAt).toEqual(MARCH)
    expect(edited.statusChangedAt).toEqual(MARCH)

    const refused = await BookCommand.edit(reader, book.id, { finishedAt: new Date('2026-01-01') })
    expect(refused).toBe('bad-dates')
  })

  // The library is ordered on the last status change, so cataloguing counts as
  // one and housekeeping does not: a corrected publisher must not lift a book
  // over one the reader just finished.
  test('stamps the status on arrival, on a move, and never on an edit', async () => {
    const LATER = new Date('2026-09-15T10:00:00.000Z')
    const book = await add('Le Nom du vent')
    expect(book.statusChangedAt).toEqual(NOW)

    const edited = await BookCommand.edit(reader, book.id, { publisher: Publisher('X') }, LATER)
    if (typeof edited === 'string') throw new Error('unreachable')
    expect(edited.statusChangedAt).toEqual(NOW)

    const same = await BookCommand.setStatus(reader, book.id, 'to-read', LATER)
    if (same === 'not-found') throw new Error('unreachable')
    expect(same.statusChangedAt).toEqual(NOW)

    const moved = await BookCommand.setStatus(reader, book.id, 'reading', LATER)
    if (moved === 'not-found') throw new Error('unreachable')
    expect(moved.statusChangedAt).toEqual(LATER)
    expect(fake.data('books', book.id)?.statusChangedAt).toEqual(LATER)
  })

  // Firestore rejects undefined outright, so an absent domain field has to
  // disappear from the document rather than be written as undefined.
  test('writes no key for a field the reader left empty', async () => {
    const book = await add('Le Nom du vent')

    const stored = fake.data('books', book.id)
    expect(stored).not.toBeNull()
    expect(Object.hasOwn(stored as object, 'synopsis')).toBe(false)
  })

  test('keeps two readers libraries apart', async () => {
    await add('Le Nom du vent')
    await BookCommand.add('reader-2' as UserId, { title: BookTitle('Autre') }, NOW)

    const mine = await BookQuery.all(reader)
    expect(mine.map((book) => String(book.title))).toEqual(['Le Nom du vent'])
  })
})

describe('placing a book in a saga by hand', () => {
  const thilliez = [AuthorName('Franck Thilliez')]
  const scanned = (title: string, volume: number) =>
    BookCommand.add(
      reader,
      {
        title: BookTitle(title),
        authors: [AuthorName('Franck Tillier')],
        series: {
          id: SeriesId('sharko-et-henebelle--franck-tillier'),
          name: SeriesName('Sharko et Henebelle'),
          volume: VolumeNumber(volume),
          kind: 'main',
        },
      },
      NOW,
    )

  // The case the feature exists for: the scan missed the saga of one volume,
  // and its siblings sit under an author the scan misspelled.
  test('gathers a volume the scan missed with the ones it filed', async () => {
    await scanned('Le Syndrome E', 1)
    const missed = await BookCommand.add(
      reader,
      { title: BookTitle('Gataca'), authors: thilliez },
      NOW,
    )
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const placed = await BookCommand.edit(reader, missed.id, {
      series: { name: SeriesName('Sharko et Henebelle'), volume: VolumeNumber(2) },
    })

    if (typeof placed === 'string') throw new Error('unreachable')
    expect(placed.series).toEqual({
      id: SeriesId('sharko-et-henebelle--franck-tillier'),
      name: SeriesName('Sharko et Henebelle'),
      volume: VolumeNumber(2),
      kind: 'main',
    })
    expect(fake.data('books', missed.id)?.series).toEqual(placed.series)
    expect(fake.docReads - before.docs).toBe(1)
    expect(fake.queryReads - before.queries).toBe(1)
  })

  // The saga screen: the saga's volumes by one query on the saga, never the
  // whole library, and never another reader's copy of the same saga.
  test('reads a saga’s volumes by a query on the saga', async () => {
    const first = await scanned('Le Syndrome E', 1)
    const second = await scanned('Gataca', 2)
    await add('Le Nom du vent')
    await BookCommand.add(
      'reader-2' as UserId,
      {
        title: BookTitle('Le Syndrome E'),
        authors: [AuthorName('Franck Tillier')],
        series: first.series,
      },
      NOW,
    )
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const volumes = await BookQuery.sagaVolumes(
      reader,
      SeriesId('sharko-et-henebelle--franck-tillier'),
    )

    expect(volumes.map((book) => book.id)).toEqual([first.id, second.id])
    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(0)
  })

  test('takes a book out of its saga when the reader clears it', async () => {
    const book = await scanned('Le Syndrome E', 1)
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const cleared = await BookCommand.edit(reader, book.id, { series: undefined })

    if (typeof cleared === 'string') throw new Error('unreachable')
    expect(cleared.series).toBeUndefined()
    expect(fake.docReads - before.docs).toBe(1)
    expect(fake.queryReads - before.queries).toBe(0)
    expect(Object.hasOwn(fake.data('books', book.id) as object, 'series')).toBe(false)
  })

  // The authors typed in the same correction are the ones the key is built from.
  test('keys a new saga on the authors corrected in the same edit', async () => {
    const book = await add('Pandemia')

    const placed = await BookCommand.edit(reader, book.id, {
      authors: thilliez,
      series: { name: SeriesName('Sharko') },
    })

    expect(placed).toMatchObject({ series: { id: 'sharko--franck-thilliez' } })
  })

  test('refuses a new saga for a book with no author, and writes nothing', async () => {
    const book = await add('Pandemia')

    const refused = await BookCommand.edit(reader, book.id, {
      publisher: undefined,
      series: { name: SeriesName('Sharko') },
    })

    expect(refused).toBe('no-author')
    expect(fake.data('books', book.id)?.series).toBeUndefined()
  })
})

describe('a saga heard and a saga read', () => {
  const bobiverse = (volume: number) => ({
    id: SeriesId('bobiverse--dennis-e-taylor'),
    name: SeriesName('Bobiverse'),
    volume: VolumeNumber(volume),
    kind: 'main' as const,
  })

  // The scan keyed the saga from the cover; the reader saved an audiobook.
  test('files a book saved as an audiobook in the saga heard', async () => {
    const book = await BookCommand.add(
      reader,
      { title: BookTitle('Nous sommes Bob'), format: 'audiobook', series: bobiverse(1) },
      NOW,
    )

    expect(book.series?.id).toBe(SeriesId('bobiverse--dennis-e-taylor--audio'))
    expect(fake.data('books', book.id)?.series).toEqual(book.series)
  })

  test('moves a book to the saga of the format the reader corrects it to', async () => {
    const book = await BookCommand.add(
      reader,
      { title: BookTitle('Nous sommes Bob'), format: 'audiobook', series: bobiverse(1) },
      NOW,
    )

    const printed = await BookCommand.edit(reader, book.id, { format: 'book' })

    if (typeof printed === 'string') throw new Error('unreachable')
    expect(printed.series).toEqual(bobiverse(1))
  })
})

describe('rating a book', () => {
  // The reader is telling us they finished it. Leaving it on the pile would make
  // every status filter lie about the same book.
  test('marks it read and stamps the reading dates', async () => {
    const book = await add('Le Nom du vent')

    const rated = await BookCommand.rate(reader, book.id, StarRating(5), NOW)

    expect(rated).not.toBe('not-found')
    if (rated === 'not-found') throw new Error('unreachable')
    expect(Number(rated.rating)).toBe(5)
    expect(rated.status).toBe('read')
    expect(rated.finishedAt).toEqual(NOW)
    expect(rated.startedAt).toEqual(NOW)
    expect(rated.statusChangedAt).toEqual(NOW)
  })

  test('answers not-found for a book the reader does not own', async () => {
    const result = await BookCommand.rate(reader, 'nope' as never, StarRating(3), NOW)

    expect(result).toBe('not-found')
  })

  // Every reader's books share one collection, so the id alone would reach them.
  test('answers not-found for a book another reader owns', async () => {
    const theirs = await BookCommand.add('reader-2' as UserId, { title: BookTitle('Dune') }, NOW)

    const result = await BookCommand.rate(reader, theirs.id, StarRating(1), NOW)

    expect(result).toBe('not-found')
    expect(fake.data('books', theirs.id)?.rating).toBeUndefined()
  })

  // Taking the stars back is not un-reading the book: the status and its dates
  // stay where rating put them.
  test('removes the rating and leaves the book read', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.rate(reader, book.id, StarRating(4), NOW)

    const unrated = await BookCommand.unrate(reader, book.id)

    if (unrated === 'not-found') throw new Error('unreachable')
    expect(unrated.rating).toBeUndefined()
    expect(unrated.status).toBe('read')
    expect(unrated.finishedAt).toEqual(NOW)
    expect(Object.hasOwn(fake.data('books', book.id) as object, 'rating')).toBe(false)
  })

  test('answers not-found when removing the rating of a book the reader does not own', async () => {
    const result = await BookCommand.unrate(reader, 'nope' as never)

    expect(result).toBe('not-found')
  })
})

describe('a heart is five stars', () => {
  // The heart is the top of the scale, not a second judgement beside it: giving
  // it rates the book five, and a rating marks the book read as ever.
  test('giving the heart rates the book five and marks it read', async () => {
    const book = await add('Le Nom du vent')

    const loved = await BookCommand.setFavorite(reader, book.id, true, NOW)

    if (loved === 'not-found') throw new Error('unreachable')
    expect(loved.favorite).toBe(true)
    expect(Number(loved.rating)).toBe(5)
    expect(loved.status).toBe('read')
    expect(loved.finishedAt).toEqual(NOW)
    expect(loved.favoritedAt).toEqual(NOW)
  })

  // Hearting it again is not news for a friend.
  test('hearting a book again keeps the date of the first heart', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.setFavorite(reader, book.id, true, NOW)

    const later = new Date(NOW.getTime() + 86_400_000)
    const again = await BookCommand.setFavorite(reader, book.id, true, later)

    if (again === 'not-found') throw new Error('unreachable')
    expect(again.favoritedAt).toEqual(NOW)
  })

  // Dropping a book is an ending the reader chose: a heart does not undo it.
  test('a dropped book keeps its status under the heart', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.setStatus(reader, book.id, 'dropped', NOW)

    const loved = await BookCommand.setFavorite(reader, book.id, true, NOW)

    if (loved === 'not-found') throw new Error('unreachable')
    expect(loved.status).toBe('dropped')
  })

  test('taking the heart back takes the stars with it, and leaves the book read', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.setFavorite(reader, book.id, true, NOW)

    const unloved = await BookCommand.setFavorite(reader, book.id, false, NOW)

    if (unloved === 'not-found') throw new Error('unreachable')
    expect(unloved.favorite).toBeUndefined()
    expect(unloved.favoritedAt).toBeUndefined()
    expect(unloved.rating).toBeUndefined()
    expect(unloved.status).toBe('read')
  })

  // Otherwise a heart would sit on three stars, which it can no longer mean.
  test('rating below five takes the heart back', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.setFavorite(reader, book.id, true, NOW)

    const rated = await BookCommand.rate(reader, book.id, StarRating(3), NOW)

    if (rated === 'not-found') throw new Error('unreachable')
    expect(Number(rated.rating)).toBe(3)
    expect(rated.favorite).toBeUndefined()
    expect(rated.favoritedAt).toBeUndefined()
  })

  test('removing the rating takes the heart back', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.setFavorite(reader, book.id, true, NOW)

    const unrated = await BookCommand.unrate(reader, book.id, NOW)

    if (unrated === 'not-found') throw new Error('unreachable')
    expect(unrated.favorite).toBeUndefined()
  })

  // Five stars given by hand are a rating, not a heart: the heart stays the
  // reader's own gesture.
  test('rating five by hand gives no heart', async () => {
    const book = await add('Le Nom du vent')

    const rated = await BookCommand.rate(reader, book.id, StarRating(5), NOW)

    if (rated === 'not-found') throw new Error('unreachable')
    expect(rated.favorite).toBeUndefined()
  })
})

describe('recording who recommended a book', () => {
  test('stores the name and the words, and forgets them when none is passed', async () => {
    const book = await add('Le Nom du vent')

    const recommended = await BookCommand.recommend(
      reader,
      book.id,
      { recommenderName: PersonName('Marie'), comment: RecommendationComment('Lis-le cet été.') },
      NOW,
    )
    if (recommended === 'not-found') throw new Error('unreachable')
    expect(recommended.recommendation).toEqual({
      recommenderName: PersonName('Marie'),
      comment: RecommendationComment('Lis-le cet été.'),
    })
    expect(fake.data('books', book.id)?.recommendation).toEqual({
      recommenderName: 'Marie',
      comment: 'Lis-le cet été.',
    })

    const cleared = await BookCommand.recommend(reader, book.id, undefined, NOW)
    if (cleared === 'not-found') throw new Error('unreachable')
    expect(cleared.recommendation).toBeUndefined()
    expect(Object.hasOwn(fake.data('books', book.id) as object, 'recommendation')).toBe(false)
  })

  test('replaces the whole recommendation rather than merging it', async () => {
    const book = await add('Le Nom du vent')
    await BookCommand.recommend(
      reader,
      book.id,
      { recommenderName: PersonName('Marie'), comment: RecommendationComment('Superbe.') },
      NOW,
    )

    const replaced = await BookCommand.recommend(
      reader,
      book.id,
      { recommenderName: PersonName('Paul') },
      NOW,
    )

    if (replaced === 'not-found') throw new Error('unreachable')
    expect(replaced.recommendation).toEqual({ recommenderName: PersonName('Paul') })
  })

  test('costs one document read and no query', async () => {
    const book = await add('Le Nom du vent')
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await BookCommand.recommend(reader, book.id, { recommenderName: PersonName('Marie') }, NOW)

    expect(fake.docReads - before.docs).toBe(1)
    expect(fake.queryReads - before.queries).toBe(0)
  })

  test("answers not-found for another reader's book", async () => {
    const book = await add('Le Nom du vent')

    const result = await BookCommand.recommend(
      'someone-else' as UserId,
      book.id,
      { recommenderName: PersonName('Marie') },
      NOW,
    )

    expect(result).toBe('not-found')
  })
})

describe('annotating a book', () => {
  test('stores the note and clears it when none is passed', async () => {
    const book = await add('Le Nom du vent')

    const annotated = await BookCommand.annotate(reader, book.id, ReadingNote('Superbe prose.'))
    expect(annotated).not.toBe('not-found')
    if (annotated === 'not-found') throw new Error('unreachable')
    expect(String(annotated.note)).toBe('Superbe prose.')

    const cleared = await BookCommand.annotate(reader, book.id, undefined)
    if (cleared === 'not-found') throw new Error('unreachable')
    expect(cleared.note).toBeUndefined()

    // An emptied note is a deletion, not an empty string the app later renders
    // as a blank block.
    const stored = fake.data('books', book.id)
    expect(Object.hasOwn(stored as object, 'note')).toBe(false)
  })
})

describe('reading the library', () => {
  // The list, the sections and the series tab all want the same rows in one
  // request. Without the per-request memoization each would pay its own query.
  // The headings add one scan of the reader's saga opinions, memoized the same
  // way, and never a lookup per saga.
  test('reads the books once and the opinions once however often it is asked', async () => {
    await add('Un')
    await add('Deux')
    const before = fake.queryReads

    await BookQuery.library(reader)
    await BookQuery.library(reader)
    await BookQuery.all(reader)

    expect(fake.queryReads - before).toBe(2)
  })

  // A save inside the same request must be visible to a read that follows it,
  // or a mutation that returns the refreshed library returns a stale one.
  test('a write drops the memoized scan', async () => {
    await add('Un')
    await BookQuery.all(reader)

    await add('Deux')

    const books = await BookQuery.all(reader)
    expect(books).toHaveLength(2)
  })
})

describe('paging the Library tab', () => {
  const shelve = async (count: number) => {
    const shelved = []
    for (let index = 0; index < count; index++)
      shelved.push(
        await BookCommand.add(
          reader,
          { title: BookTitle(`Tome ${String(index).padStart(2, '0')}`) },
          new Date(NOW.getTime() - index * 60_000),
        ),
      )
    return shelved
  }

  // The point of the cursor: a page costs its own rows, not the library.
  test('reads a page and one row more, however large the library', async () => {
    await shelve(30)
    const before = fake.queriedDocs

    const { books, hasMore } = await BookQuery.libraryPage(reader, { limit: 10 }, {})

    expect(books.map((book) => String(book.title))).toEqual(
      Array.from({ length: 10 }, (_, index) => `Tome ${String(index).padStart(2, '0')}`),
    )
    expect(hasMore).toBe(true)
    expect(fake.queriedDocs - before).toBe(11)
  })

  test('carries on after the last book of the page before', async () => {
    const shelved = await shelve(12)

    const { books, hasMore } = await BookQuery.libraryPage(
      reader,
      { limit: 10, after: shelved[9]?.id },
      {},
    )

    expect(books.map((book) => book.id)).toEqual([shelved[10]?.id, shelved[11]?.id])
    expect(hasMore).toBe(false)
  })

  test('keeps only the status asked for', async () => {
    const [reading] = await shelve(3)
    if (reading) await BookCommand.setStatus(reader, reading.id, 'reading', NOW)

    const { books } = await BookQuery.libraryPage(reader, { limit: 10 }, { status: 'reading' })

    expect(books.map((book) => book.id)).toEqual([reading?.id])
  })

  // A book given up on has a filter of its own; the default view is what the
  // reader is reading, will read and has read.
  test('leaves the dropped books out of the default view, not out of their filter', async () => {
    const [dropped] = await shelve(3)
    if (dropped) await BookCommand.setStatus(reader, dropped.id, 'dropped', NOW)

    const all = await BookQuery.libraryPage(reader, { limit: 10 }, {})
    const filtered = await BookQuery.libraryPage(reader, { limit: 10 }, { status: 'dropped' })

    expect(all.books.map((book) => book.id)).not.toContain(dropped?.id)
    expect(all.books).toHaveLength(2)
    expect(filtered.books.map((book) => book.id)).toEqual([dropped?.id])
  })

  test('restarts from the top when the cursor book is gone', async () => {
    const shelved = await shelve(3)
    const gone = shelved[1]
    if (gone) await BookCommand.remove(reader, gone.id)

    const { books } = await BookQuery.libraryPage(reader, { limit: 10, after: gone?.id }, {})

    expect(books).toHaveLength(2)
  })

  // Right after a deploy, an index may still be building: the tab answers
  // from the scan it used before, slower but whole.
  test('falls back on the full scan while its index is missing', async () => {
    await shelve(3)
    fake.failNextQueryWith(
      Object.assign(new Error('FAILED_PRECONDITION: The query requires an index'), { code: 9 }),
    )

    const { books } = await BookQuery.libraryPage(reader, { limit: 10 }, { favorite: false })

    expect(books).toHaveLength(3)
  })

  test('never hands the stored shelf date back as part of a book', async () => {
    const [book] = await shelve(1)
    expect(fake.data('books', book?.id ?? '')?.shelvedAt).toEqual(NOW)

    const { books } = await BookQuery.libraryPage(reader, { limit: 10 }, {})

    expect(books[0]).not.toHaveProperty('shelvedAt')
  })
})

describe('reading the library back within a request', () => {
  // A sync writes book after book and then reads the shelf: the scan it already
  // holds follows the writes rather than being paid for again.
  test('follows a direct write without scanning the library again', async () => {
    const first = await add('Un')
    await BookQuery.all(reader)
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await BookCommand.setStatus(reader, first.id, 'reading', NOW)
    const second = await add('Deux')

    const library = await BookQuery.all(reader)
    expect(library.map((book) => [book.id, book.status])).toEqual([
      [first.id, 'reading'],
      [second.id, 'to-read'],
    ])
    expect(fake.queryReads).toBe(before.queries)
    expect(fake.docReads).toBe(before.docs)
  })
})

describe('deleting', () => {
  test('removes the book and says so', async () => {
    const book = await add('Le Nom du vent')

    expect(await BookCommand.remove(reader, book.id)).toBe('removed')
    expect(await BookQuery.byId(reader, book.id)).toBeNull()
  })

  test('wipes the whole library on account deletion', async () => {
    await add('Un')
    await add('Deux')

    await BookCommand.deleteAllForUser(reader)

    expect(await BookQuery.all(reader)).toHaveLength(0)
  })

  test('wipes a library larger than one batch can carry', async () => {
    for (let index = 0; index < 650; index++) await add(`Tome ${index}`)

    await BookCommand.deleteAllForUser(reader)

    expect(await BookQuery.all(reader)).toHaveLength(0)
  })
})
