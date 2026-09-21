import { describe, expect, test } from 'bun:test'
import {
  datesAfterStatusChange,
  groupedBySeries,
  readVolumeNumbersOf,
  shelfPageOf,
  shelvedOf,
  statusAfterRating,
  statusChangedAtOf,
  statusStampAfterChange,
  subgenresOf,
} from '~/domain/book/business-rules'
import { BookId, Subgenre } from '~/domain/book/primitives'
import type { Book, BookLanguage, BookView, Genre } from '~/domain/book/types'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { VolumeKind } from '~/domain/series/types'
import { BookTitle, UserId } from '~/domain/shared/primitives'

const NOW = new Date('2026-09-14T10:00:00.000Z')
const EARLIER = new Date('2026-01-02T08:00:00.000Z')
const LATER = new Date('2026-09-15T10:00:00.000Z')

type BookSpec = {
  title: string
  series?: { name: string; volume?: number; kind?: VolumeKind }
  status?: Book['status']
  language?: BookLanguage
  genre?: Genre
  addedAt?: Date
  statusChangedAt?: Date
  startedAt?: Date
  finishedAt?: Date
}

const book = (spec: BookSpec): BookView => ({
  id: BookId(spec.title),
  userId: UserId('reader'),
  title: BookTitle(spec.title),
  authors: [],
  format: 'book',
  subgenres: [],
  narrators: [],
  status: spec.status ?? 'to-read',
  language: spec.language,
  genre: spec.genre,
  hidden: false,
  addedAt: spec.addedAt ?? NOW,
  statusChangedAt: spec.statusChangedAt,
  startedAt: spec.startedAt,
  finishedAt: spec.finishedAt,
  series: spec.series
    ? {
        id: SeriesId(spec.series.name.toLowerCase()),
        name: SeriesName(spec.series.name),
        volume: spec.series.volume ? VolumeNumber(spec.series.volume) : undefined,
        kind: spec.series.kind ?? 'main',
      }
    : undefined,
})

describe('groupedBySeries', () => {
  test('gathers the volumes of a saga under one heading, along the spine', () => {
    const sections = groupedBySeries([
      book({ title: 'Volume two', series: { name: 'Saga', volume: 2 } }),
      book({ title: 'Volume one', series: { name: 'Saga', volume: 1 } }),
    ])
    expect(sections).toHaveLength(1)
    expect(String(sections[0].series?.name)).toBe('Saga')
    expect(sections[0].books.map((entry) => String(entry.title))).toEqual([
      'Volume one',
      'Volume two',
    ])
  })

  // The library shows what the reader owns. A saga of fourteen volumes of which
  // they own two is two rows, not fourteen: the catalogue never adds a row here.
  test('shows only the volumes the reader owns', () => {
    const sections = groupedBySeries([
      book({ title: 'Volume one', series: { name: 'Saga', volume: 1 } }),
      book({ title: 'Volume two', series: { name: 'Saga', volume: 2 } }),
    ])
    expect(sections[0].books).toHaveLength(2)
  })

  // Grouping only from two volumes up would make a book jump between sections
  // when an unrelated one is added, which reads as a bug.
  test('gives a saga its own section from the first volume owned', () => {
    const sections = groupedBySeries([
      book({ title: 'Alone', series: { name: 'Saga', volume: 1 } }),
    ])
    expect(sections[0].series?.name).toBeDefined()
  })

  test('puts related works after the numbered spine within a section', () => {
    const sections = groupedBySeries([
      book({ title: 'Side story', series: { name: 'Saga', kind: 'spin-off' } }),
      book({ title: 'Volume one', series: { name: 'Saga', volume: 1 } }),
    ])
    expect(sections[0].books.map((entry) => String(entry.title))).toEqual([
      'Volume one',
      'Side story',
    ])
  })

  // The shelf is the leftovers. Putting it first would bury the structure the
  // reader opened the list for.
  test('trails the sagas with a single shelf of standalone books', () => {
    const sections = groupedBySeries([
      book({ title: 'Standalone' }),
      book({ title: 'Volume one', series: { name: 'Saga', volume: 1 } }),
    ])
    expect(sections).toHaveLength(2)
    expect(sections[0].series?.name).toBeDefined()
    expect(sections[1].series).toBeUndefined()
    expect(sections[1].books.map((entry) => String(entry.title))).toEqual(['Standalone'])
  })

  // The saga the reader last picked up or put down is the one they are most
  // likely to come back for. One recent move lifts its whole saga: the section
  // moves as one.
  test('puts the saga whose status last changed first, whole', () => {
    const sections = groupedBySeries([
      book({ title: 'A1', series: { name: 'Alpha', volume: 1 }, statusChangedAt: EARLIER }),
      book({ title: 'A2', series: { name: 'Alpha', volume: 2 }, statusChangedAt: NOW }),
      book({ title: 'Z1', series: { name: 'Zeta', volume: 1 }, statusChangedAt: LATER }),
      book({ title: 'Z2', series: { name: 'Zeta', volume: 2 }, statusChangedAt: EARLIER }),
    ])
    expect(sections.map((section) => String(section.series?.name))).toEqual(['Zeta', 'Alpha'])
    expect(sections[1].books.map((entry) => String(entry.title))).toEqual(['A1', 'A2'])
  })

  test('breaks a tie on status change by name', () => {
    const sections = groupedBySeries([
      book({ title: 'Z1', series: { name: 'Zeta', volume: 1 } }),
      book({ title: 'A1', series: { name: 'Alpha', volume: 1 } }),
    ])
    expect(sections.map((section) => String(section.series?.name))).toEqual(['Alpha', 'Zeta'])
  })

  // A record from before the stamp existed is not older than everything: it
  // ranks on the day it was added, which is when it landed on the pile.
  test('ranks a record never stamped on the day it was added', () => {
    const sections = groupedBySeries([
      book({ title: 'Old', statusChangedAt: EARLIER }),
      book({ title: 'Unstamped' }),
    ])
    expect(sections[0].books.map((entry) => String(entry.title))).toEqual(['Unstamped', 'Old'])
  })

  test('keeps the shelf behind the sagas however recent its books are', () => {
    const sections = groupedBySeries([
      book({ title: 'Fresh standalone', statusChangedAt: LATER }),
      book({ title: 'V1', series: { name: 'Saga', volume: 1 }, statusChangedAt: EARLIER }),
    ])
    expect(sections.map((section) => section.series?.name)).toEqual([SeriesName('Saga'), undefined])
  })
})

describe('groupedBySeries, by reading status', () => {
  const names = (sections: { series?: { name: string } }[]) =>
    sections.map((section) => (section.series ? String(section.series.name) : 'shelf'))

  // What is being read comes first, then the pile, then what is finished,
  // however recently a finished saga moved.
  test('orders the sagas in progress, then on the pile, then finished', () => {
    const sections = groupedBySeries([
      book({ title: 'F1', series: { name: 'Finished' }, status: 'read', statusChangedAt: LATER }),
      book({ title: 'P1', series: { name: 'Pile' }, status: 'to-read', statusChangedAt: NOW }),
      book({
        title: 'R1',
        series: { name: 'Reading' },
        status: 'reading',
        statusChangedAt: EARLIER,
      }),
    ])
    expect(names(sections)).toEqual(['Reading', 'Pile', 'Finished'])
  })

  // One volume in progress is enough: the saga is what the reader is in.
  test('ranks a saga by its most active volume', () => {
    const sections = groupedBySeries([
      book({ title: 'P1', series: { name: 'Pile', volume: 1 }, status: 'to-read' }),
      book({ title: 'M1', series: { name: 'Mixed', volume: 1 }, status: 'read' }),
      book({ title: 'M2', series: { name: 'Mixed', volume: 2 }, status: 'reading' }),
    ])
    expect(names(sections)).toEqual(['Mixed', 'Pile'])
  })

  test('trails each tier with its own standalone books', () => {
    const sections = groupedBySeries([
      book({ title: 'Done alone', status: 'read' }),
      book({ title: 'Reading alone', status: 'reading' }),
      book({ title: 'R1', series: { name: 'Reading' }, status: 'reading' }),
      book({ title: 'F1', series: { name: 'Finished' }, status: 'read' }),
    ])
    expect(names(sections)).toEqual(['Reading', 'shelf', 'Finished', 'shelf'])
    expect(sections[1].books.map((entry) => String(entry.title))).toEqual(['Reading alone'])
  })

  // Two headless shelves back to back read as one shelf with a gap in it.
  test('draws the shelves of two tiers as one when no saga stands between them', () => {
    const sections = groupedBySeries([
      book({ title: 'Pile alone', status: 'to-read' }),
      book({ title: 'Reading alone', status: 'reading' }),
    ])
    expect(sections).toHaveLength(1)
    expect(sections[0].books.map((entry) => String(entry.title))).toEqual([
      'Reading alone',
      'Pile alone',
    ])
  })
})

// A record from before the stamp existed still says when its status was set:
// the reading dates are written by the very move the stamp would have recorded.
describe('statusChangedAtOf', () => {
  test('prefers the stamp when there is one', () => {
    const at = statusChangedAtOf(
      book({ title: 'T', status: 'read', statusChangedAt: LATER, finishedAt: EARLIER }),
    )
    expect(at).toBe(LATER)
  })

  test('falls back on the date the status implies', () => {
    expect(statusChangedAtOf(book({ title: 'T', status: 'read', finishedAt: EARLIER }))).toBe(
      EARLIER,
    )
    expect(statusChangedAtOf(book({ title: 'T', status: 'reading', startedAt: EARLIER }))).toBe(
      EARLIER,
    )
    expect(statusChangedAtOf(book({ title: 'T', status: 'to-read', startedAt: EARLIER }))).toBe(NOW)
  })
})

describe('statusStampAfterChange', () => {
  test('stamps a move and not a status chosen again', () => {
    expect(statusStampAfterChange({ status: 'to-read' }, 'reading', NOW)).toEqual({
      statusChangedAt: NOW,
    })
    expect(statusStampAfterChange({ status: 'reading' }, 'reading', NOW)).toEqual({})
  })
})

describe('readVolumeNumbersOf', () => {
  // A volume in progress is not done, and counting it would mark a saga complete
  // while the reader is still in the middle of its last book.
  test('counts only finished volumes', () => {
    const numbers = readVolumeNumbersOf([
      book({ title: 'One', series: { name: 'Saga', volume: 1 }, status: 'read' }),
      book({ title: 'Two', series: { name: 'Saga', volume: 2 }, status: 'reading' }),
    ])
    expect([...numbers]).toEqual([1])
  })
})

describe('datesAfterStatusChange', () => {
  test('stamps a start the first time a book is opened, and keeps it after that', () => {
    const fresh = datesAfterStatusChange({ status: 'to-read' }, 'reading', NOW)
    expect(fresh.startedAt).toBe(NOW)

    const resumed = datesAfterStatusChange(
      { status: 'reading', startedAt: EARLIER },
      'reading',
      NOW,
    )
    expect(resumed.startedAt).toBe(EARLIER)
  })

  // The reader read it, they just never told the app. Leaving a finished book
  // with no beginning would make the reading statistics nonsense.
  test('finishing a book that was never started stamps both dates', () => {
    const dates = datesAfterStatusChange({ status: 'to-read' }, 'read', NOW)
    expect(dates.startedAt).toBe(NOW)
    expect(dates.finishedAt).toBe(NOW)
  })

  // Moving back to the pile is the reader saying the reading did not happen.
  // Keeping a finish date would surface the book in statistics forever.
  test('going back to the pile clears both dates', () => {
    const dates = datesAfterStatusChange(
      { status: 'read', startedAt: EARLIER, finishedAt: NOW },
      'to-read',
      NOW,
    )
    expect(dates.startedAt).toBeUndefined()
    expect(dates.finishedAt).toBeUndefined()
  })

  test('reopening a finished book clears the finish date but keeps the start', () => {
    const dates = datesAfterStatusChange(
      { status: 'read', startedAt: EARLIER, finishedAt: NOW },
      'reading',
      NOW,
    )
    expect(dates.startedAt).toBe(EARLIER)
    expect(dates.finishedAt).toBeUndefined()
  })
})

describe('a dropped book', () => {
  // Not read, so no finish date to count in the statistics; but it was opened.
  test('keeps its start, stamping one if it had none, and never a finish', () => {
    expect(datesAfterStatusChange({ status: 'to-read' }, 'dropped', NOW)).toEqual({
      startedAt: NOW,
      finishedAt: undefined,
    })
    expect(
      datesAfterStatusChange(
        { status: 'read', startedAt: EARLIER, finishedAt: NOW },
        'dropped',
        NOW,
      ),
    ).toEqual({ startedAt: EARLIER, finishedAt: undefined })
  })

  // One star is often exactly why it was dropped.
  test('stays dropped when rated, where any other book becomes read', () => {
    expect(statusAfterRating('dropped')).toBe('dropped')
    expect(statusAfterRating('to-read')).toBe('read')
  })

  test('sits last, after the books finished, the latest put down first', () => {
    const shelved = shelvedOf(
      [
        book({ title: 'Dropped long ago', status: 'dropped', statusChangedAt: EARLIER }),
        book({ title: 'Finished', status: 'read', finishedAt: EARLIER }),
        book({ title: 'Just dropped', status: 'dropped', statusChangedAt: LATER }),
        book({ title: 'Pile' }),
      ],
      'by-status',
    )
    expect(shelved.map((entry) => String(entry.title))).toEqual([
      'Pile',
      'Finished',
      'Just dropped',
      'Dropped long ago',
    ])
  })
})

describe('groupedBySeries, across languages', () => {
  // The editions of a translation are different objects from the editions of
  // the original — other covers, other titles, read at other times — and one
  // heading over both hid that.
  test('splits a saga held in two languages into two sections', () => {
    const sections = groupedBySeries([
      book({ title: 'Dune', series: { name: 'Dune', volume: 1 }, language: 'fr' }),
      book({ title: 'Dune Messiah', series: { name: 'Dune', volume: 2 }, language: 'en' }),
    ])

    expect(sections.map((section) => section.series?.language)).toEqual(['en', 'fr'])
    expect(sections.map((section) => section.books.map((entry) => entry.title))).toEqual([
      [BookTitle('Dune Messiah')],
      [BookTitle('Dune')],
    ])
  })

  test('keeps one section for a saga read in a single language', () => {
    const sections = groupedBySeries([
      book({ title: 'Dune', series: { name: 'Dune', volume: 1 }, language: 'fr' }),
      book({ title: 'Le Messie de Dune', series: { name: 'Dune', volume: 2 }, language: 'fr' }),
    ])

    expect(sections).toHaveLength(1)
    expect(sections[0]?.books).toHaveLength(2)
  })

  // Unknown is not French. Every book catalogued before the scan started reading
  // the cover has no language, and folding those into whichever language happens
  // to sort first would state something nobody established.
  test('gathers books with no recorded language in their own trailing section', () => {
    const sections = groupedBySeries([
      book({ title: 'Dune', series: { name: 'Dune', volume: 1 } }),
      book({ title: 'Le Messie de Dune', series: { name: 'Dune', volume: 2 }, language: 'fr' }),
    ])

    expect(sections.map((section) => section.series?.language)).toEqual(['fr', undefined])
  })
})

describe('subgenresOf', () => {
  const tagged = (...subgenres: string[]) => ({ subgenres: subgenres.map(Subgenre) })

  test('proposes the most used first, then alphabetically', () => {
    const proposed = subgenresOf([
      tagged('Space opera', 'Jeunesse'),
      tagged('Dark fantasy'),
      tagged('Space opera'),
    ])
    expect(proposed.map(String)).toEqual(['Space Opera', 'Dark Fantasy', 'Jeunesse'])
  })

  // Two spellings of one word are one word: the form must not propose both.
  test('folds case, keeping the first spelling seen', () => {
    const proposed = subgenresOf([tagged('Dark fantasy'), tagged('dark FANTASY')])
    expect(proposed.map(String)).toEqual(['Dark Fantasy'])
  })
})

describe('shelvedOf', () => {
  const titles = (books: readonly BookView[]) => books.map((entry) => String(entry.title))

  test('tiers by status, each tier on the date that names its move', () => {
    const shelved = shelvedOf(
      [
        book({ title: 'Old pile', addedAt: EARLIER }),
        book({ title: 'Finished long ago', status: 'read', finishedAt: EARLIER }),
        book({ title: 'New pile', addedAt: LATER }),
        book({ title: 'Just finished', status: 'read', finishedAt: LATER }),
        book({ title: 'Started long ago', status: 'reading', startedAt: EARLIER }),
        book({ title: 'Just started', status: 'reading', startedAt: LATER }),
      ],
      'by-status',
    )
    expect(titles(shelved)).toEqual([
      'Just started',
      'Started long ago',
      'New pile',
      'Old pile',
      'Just finished',
      'Finished long ago',
    ])
  })

  // A saga is not gathered any more: each volume sits where its own status puts it.
  test('splits a saga across the tiers of its volumes', () => {
    const shelved = shelvedOf(
      [
        book({ title: 'V1', series: { name: 'Saga', volume: 1 }, status: 'read' }),
        book({ title: 'Alone', status: 'to-read' }),
        book({ title: 'V2', series: { name: 'Saga', volume: 2 }, status: 'reading' }),
      ],
      'by-status',
    )
    expect(titles(shelved)).toEqual(['V2', 'Alone', 'V1'])
  })

  test('sections by genre in the closed list order, no genre last, tiered inside', () => {
    const shelved = shelvedOf(
      [
        book({ title: 'Untagged' }),
        book({ title: 'Essay read', genre: 'essay', status: 'read' }),
        book({ title: 'Fantasy pile', genre: 'fantasy' }),
        book({ title: 'Essay reading', genre: 'essay', status: 'reading' }),
        book({ title: 'Fantasy reading', genre: 'fantasy', status: 'reading' }),
      ],
      'by-genre',
    )
    expect(titles(shelved)).toEqual([
      'Fantasy reading',
      'Fantasy pile',
      'Essay reading',
      'Essay read',
      'Untagged',
    ])
  })

  // A record whose reading dates were never stamped still has a place.
  test('ranks an unstamped book on the day it was added', () => {
    const shelved = shelvedOf(
      [
        book({ title: 'Stamped', status: 'read', addedAt: LATER, finishedAt: NOW }),
        book({ title: 'Imported', status: 'read', addedAt: LATER }),
      ],
      'by-status',
    )
    expect(titles(shelved)).toEqual(['Imported', 'Stamped'])
  })
})

describe('shelfPageOf', () => {
  const books = ['A', 'B', 'C'].map((title) => book({ title }))
  const titles = (page: { books: readonly BookView[] }) => page.books.map((b) => String(b.title))

  test('cuts after the cursor and says whether more follows', () => {
    const first = shelfPageOf(books, 2)
    expect(titles(first)).toEqual(['A', 'B'])
    expect(first.hasMore).toBe(true)

    const second = shelfPageOf(books, 2, BookId('B'))
    expect(titles(second)).toEqual(['C'])
    expect(second.hasMore).toBe(false)
  })

  test('restarts from the top when the cursor names a book no longer there', () => {
    const page = shelfPageOf(books, 10, BookId('gone'))
    expect(titles(page)).toEqual(['A', 'B', 'C'])
    expect(page.hasMore).toBe(false)
  })
})
