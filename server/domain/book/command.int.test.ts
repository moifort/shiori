import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { BookTitle } = await import('~/domain/shared/primitives')
const { StarRating, ReadingNote, Publisher, PageCount } = await import('~/domain/book/primitives')

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

    if (edited === 'not-found') throw new Error('unreachable')
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

  // The library is ordered on the last status change, so cataloguing counts as
  // one and housekeeping does not: a corrected publisher must not lift a book
  // over one the reader just finished.
  test('stamps the status on arrival, on a move, and never on an edit', async () => {
    const LATER = new Date('2026-09-15T10:00:00.000Z')
    const book = await add('Le Nom du vent')
    expect(book.statusChangedAt).toEqual(NOW)

    const edited = await BookCommand.edit(reader, book.id, { publisher: Publisher('X') }, LATER)
    if (edited === 'not-found') throw new Error('unreachable')
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
})
