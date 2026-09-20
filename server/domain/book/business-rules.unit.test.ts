import { describe, expect, test } from 'bun:test'
import {
  datesAfterStatusChange,
  groupedBySeries,
  readVolumeNumbersOf,
} from '~/domain/book/business-rules'
import { BookId } from '~/domain/book/primitives'
import type { Book, BookLanguage, BookView } from '~/domain/book/types'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { VolumeKind } from '~/domain/series/types'
import { BookTitle, UserId } from '~/domain/shared/primitives'

const NOW = new Date('2026-09-14T10:00:00.000Z')
const EARLIER = new Date('2026-01-02T08:00:00.000Z')

type BookSpec = {
  title: string
  series?: { name: string; volume?: number; kind?: VolumeKind }
  status?: Book['status']
  language?: BookLanguage
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
  hidden: false,
  addedAt: NOW,
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

  test('sorts sagas by name', () => {
    const sections = groupedBySeries([
      book({ title: 'Z1', series: { name: 'Zeta', volume: 1 } }),
      book({ title: 'A1', series: { name: 'Alpha', volume: 1 } }),
    ])
    expect(sections.map((section) => String(section.series?.name))).toEqual(['Alpha', 'Zeta'])
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
