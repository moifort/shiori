import { describe, expect, test } from 'bun:test'
import {
  datesAfterCorrection,
  datesAfterStatusChange,
  groupedBySeries,
  inSagaOrder,
  listeningProgressOf,
  membershipFor,
  ratedShelfOf,
  readVolumeNumbersOf,
  retaggedAfterEdit,
  sagaNamesOf,
  seriesInFormat,
  shelfPageOf,
  shelvedOf,
  shownRatingOf,
  statusAfterRating,
  statusChangedAtOf,
  statusStampAfterChange,
  storedRecommendation,
  subgenresOf,
  vocabularyOf,
} from '~/domain/book/business-rules'
import {
  BookId,
  ListeningMinutes,
  RecommendationComment,
  StarRating,
  Subgenre,
} from '~/domain/book/primitives'
import type { Book, BookLanguage, BookView, Genre } from '~/domain/book/types'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { VolumeKind } from '~/domain/series/types'
import { AuthorName, BookTitle, PersonName, UserId } from '~/domain/shared/primitives'
import { slugify } from '~/utils/slug'

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

  // A related work numbered on its own shelf is not the main volume of the
  // same number: reading novella 2 does not finish tome 2.
  test('counts only the main spine', () => {
    const numbers = readVolumeNumbersOf([
      book({ title: 'One', series: { name: 'Saga', volume: 1 }, status: 'read' }),
      book({ title: 'Side', series: { name: 'Saga', volume: 2, kind: 'novella' }, status: 'read' }),
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

describe('datesAfterCorrection', () => {
  const read = { status: 'read' as const, addedAt: EARLIER, startedAt: EARLIER, finishedAt: NOW }

  test('takes the dates the reader typed, and leaves the others', () => {
    const corrected = new Date('2026-03-01T12:00:00.000Z')
    expect(datesAfterCorrection(read, { startedAt: corrected }, NOW)).toEqual({
      startedAt: corrected,
    })
  })

  // The library is ordered on when a book last changed status. Saying "I
  // finished it in March" is saying when that move happened.
  test('moves the status stamp with the date that marks the current status', () => {
    const march = new Date('2026-03-01T12:00:00.000Z')
    expect(datesAfterCorrection(read, { finishedAt: march }, NOW)).toEqual({
      finishedAt: march,
      statusChangedAt: march,
    })
    expect(
      datesAfterCorrection({ status: 'reading', addedAt: EARLIER }, { startedAt: march }, NOW),
    ).toEqual({ startedAt: march, statusChangedAt: march })
    expect(
      datesAfterCorrection({ status: 'to-read', addedAt: EARLIER }, { addedAt: march }, NOW),
    ).toEqual({ addedAt: march, statusChangedAt: march })
  })

  // Dropping is its own moment, which no typed date says.
  test('leaves the stamp of a dropped book where it is', () => {
    const march = new Date('2026-03-01T12:00:00.000Z')
    expect(
      datesAfterCorrection({ status: 'dropped', addedAt: EARLIER }, { startedAt: march }, NOW),
    ).toEqual({ startedAt: march })
  })

  test('refuses a finish before the start', () => {
    expect(datesAfterCorrection(read, { finishedAt: new Date('2025-12-01') }, NOW)).toBe(
      'bad-dates',
    )
    expect(datesAfterCorrection(read, { startedAt: LATER }, LATER)).toBe('bad-dates')
  })

  // A day of slack for a phone whose clock runs ahead of the server's.
  test('refuses a date in the future, past a day of clock drift', () => {
    const hourAhead = new Date(NOW.getTime() + 3_600_000)
    expect(datesAfterCorrection(read, { finishedAt: hourAhead }, NOW)).toEqual({
      finishedAt: hourAhead,
      statusChangedAt: hourAhead,
    })
    const twoDaysAhead = new Date(NOW.getTime() + 2 * 86_400_000)
    expect(datesAfterCorrection(read, { addedAt: twoDaysAhead }, NOW)).toBe('bad-dates')
  })

  test('refuses a date that does not parse', () => {
    expect(datesAfterCorrection(read, { addedAt: new Date('not a date') }, NOW)).toBe('bad-dates')
  })

  // The dates follow from the status: a book on the pile was never opened, and
  // only a read one was finished.
  test('refuses a date the status does not carry', () => {
    const toRead = { status: 'to-read' as const, addedAt: EARLIER }
    expect(datesAfterCorrection(toRead, { startedAt: EARLIER }, NOW)).toBe('bad-dates')
    const reading = { status: 'reading' as const, addedAt: EARLIER, startedAt: EARLIER }
    expect(datesAfterCorrection(reading, { finishedAt: NOW }, NOW)).toBe('bad-dates')
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

  // It carries a start and no finish, so it sits in the timeline on its start.
  test('is shelved on the day it was started, among the others', () => {
    const shelved = shelvedOf([
      book({ title: 'Dropped', status: 'dropped', addedAt: EARLIER, startedAt: NOW }),
      book({ title: 'Finished', status: 'read', finishedAt: LATER }),
      book({ title: 'Pile', addedAt: EARLIER }),
    ])
    expect(shelved.map((entry) => String(entry.title))).toEqual(['Finished', 'Dropped', 'Pile'])
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
  const tagged = (...subgenres: string[]) => ({
    subgenres: subgenres.map((label) => ({ label: Subgenre(label), language: 'fr' as const })),
  })

  test('proposes the most used first, then alphabetically', () => {
    const proposed = subgenresOf(
      [tagged('Space opera', 'Jeunesse'), tagged('Dark fantasy'), tagged('Space opera')],
      'fr',
    )
    expect(proposed.map(String)).toEqual(['Space Opera', 'Dark Fantasy', 'Jeunesse'])
  })

  // A French app proposes what was written in French, and nothing else.
  test('proposes only the labels written in the language asked for', () => {
    const shelf = [
      tagged('Jeunesse'),
      { subgenres: [{ label: Subgenre('Grimdark'), language: 'en' as const }] },
    ]
    expect(subgenresOf(shelf, 'fr').map(String)).toEqual(['Jeunesse'])
    expect(subgenresOf(shelf, 'en').map(String)).toEqual(['Grimdark'])
  })

  // Two spellings of one word are one word: the form must not propose both.
  test('folds case, keeping the first spelling seen', () => {
    const proposed = subgenresOf([tagged('Dark fantasy'), tagged('dark FANTASY')], 'fr')
    expect(proposed.map(String)).toEqual(['Dark Fantasy'])
  })
})

describe('sagaNamesOf', () => {
  const inSaga = (name: string) => ({
    series: { id: SeriesId(slugify(name)), name: SeriesName(name), kind: 'main' as VolumeKind },
  })

  test('names every saga held once, alphabetically, and leaves standalone books out', () => {
    const names = sagaNamesOf([inSaga('Sharko'), {}, inSaga('Dune'), inSaga('Sharko')])
    expect(names.map(String)).toEqual(['Dune', 'Sharko'])
  })

  // A saga held in two languages, or spelt two ways, is one name to propose.
  test('folds case, keeping the first spelling seen', () => {
    expect(sagaNamesOf([inSaga('La Passe-miroir'), inSaga('la passe-miroir')]).map(String)).toEqual(
      ['La Passe-miroir'],
    )
  })
})

describe('vocabularyOf', () => {
  test('draws the subgenres and the sagas from the same books', () => {
    const vocabulary = vocabularyOf(
      [
        {
          subgenres: [{ label: Subgenre('Space opera'), language: 'fr' as const }],
          series: { id: SeriesId('dune'), name: SeriesName('Dune'), kind: 'main' as VolumeKind },
        },
      ],
      'fr',
    )
    expect(vocabulary).toEqual({
      subgenres: [Subgenre('Space opera')],
      sagas: [SeriesName('Dune')],
    })
  })
})

describe('retaggedAfterEdit', () => {
  const tag = (label: string, language: 'fr' | 'en') => ({ label: Subgenre(label), language })

  // Editing the list is not rewriting what was already on it.
  test('keeps the language of a label the book already carried, tags a new one', () => {
    const edited = retaggedAfterEdit(
      [tag('grimdark', 'fr'), tag('Roman noir', 'fr')],
      [tag('Grimdark', 'en')],
    )
    expect(edited.map(({ label, language }) => [String(label), language])).toEqual([
      ['Grimdark', 'en'],
      ['Roman Noir', 'fr'],
    ])
  })
})

describe('shelvedOf', () => {
  const titles = (books: readonly BookView[]) => books.map((entry) => String(entry.title))

  // Status no longer tiers the list: one timeline, whatever each book's state.
  test('orders every book newest first on its finish, else start, else added date', () => {
    const shelved = shelvedOf([
      book({ title: 'Old pile', addedAt: EARLIER }),
      book({ title: 'Finished long ago', status: 'read', addedAt: EARLIER, finishedAt: EARLIER }),
      book({ title: 'New pile', addedAt: LATER }),
      book({ title: 'Just finished', status: 'read', addedAt: EARLIER, finishedAt: LATER }),
      book({ title: 'Started', status: 'reading', addedAt: EARLIER, startedAt: NOW }),
    ])
    expect(titles(shelved)).toEqual([
      'Just finished',
      'New pile',
      'Started',
      'Finished long ago',
      'Old pile',
    ])
  })

  // The finish date wins over a later start: a reread stays where it ended.
  test('shelves a book on its finish date even when its start is later', () => {
    const shelved = shelvedOf([
      book({ title: 'Reread', status: 'read', startedAt: LATER, finishedAt: EARLIER }),
      book({ title: 'Middle', addedAt: NOW }),
    ])
    expect(titles(shelved)).toEqual(['Middle', 'Reread'])
  })

  // A saga is not gathered: each volume sits on its own date.
  test('splits a saga across the dates of its volumes', () => {
    const shelved = shelvedOf([
      book({ title: 'V1', series: { name: 'Saga', volume: 1 }, finishedAt: EARLIER }),
      book({ title: 'Alone', addedAt: NOW }),
      book({ title: 'V2', series: { name: 'Saga', volume: 2 }, startedAt: LATER }),
    ])
    expect(titles(shelved)).toEqual(['V2', 'Alone', 'V1'])
  })

  // A record whose reading dates were never stamped still has a place.
  test('ranks an unstamped book on the day it was added, ties by title', () => {
    const shelved = shelvedOf([
      book({ title: 'Stamped', status: 'read', addedAt: EARLIER, finishedAt: LATER }),
      book({ title: 'Imported B', status: 'read', addedAt: LATER }),
      book({ title: 'Imported A', status: 'read', addedAt: LATER }),
    ])
    expect(titles(shelved)).toEqual(['Imported A', 'Imported B', 'Stamped'])
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

describe('the stars a book shows', () => {
  const kingkiller = SeriesId('kingkiller--rothfuss')
  const inSaga = { id: kingkiller, name: SeriesName('Kingkiller'), kind: 'main' as const }
  const seriesRatings = new Map([[kingkiller, StarRating(4)]])

  test('are its own when the reader rated it', () => {
    expect(shownRatingOf({ rating: StarRating(2), series: inSaga }, seriesRatings)).toBe(
      StarRating(2),
    )
  })

  test("are the saga's when the reader rated the saga and not the book", () => {
    expect(shownRatingOf({ series: inSaga }, seriesRatings)).toBe(StarRating(4))
  })

  test('are none for an unrated standalone book', () => {
    expect(shownRatingOf({}, seriesRatings)).toBeUndefined()
  })
})

describe('the rated shelf', () => {
  const kingkiller = SeriesId('kingkiller--rothfuss')
  const inSaga = { id: kingkiller, name: SeriesName('Kingkiller'), kind: 'main' as const }
  const book = (title: string, overrides: Partial<Book>): Book => ({
    id: BookId(title),
    userId: UserId('reader'),
    title: BookTitle(title),
    authors: [],
    format: 'book',
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-01'),
    ...overrides,
  })

  // Best first, and among equals the order of the shelf, so the view reads as
  // the library does within each band of stars.
  test('keeps the rated books, best first, then in shelf order', () => {
    const shelf = ratedShelfOf(
      [
        book('unrated', { finishedAt: new Date('2026-05-01') }),
        book('older-three', { rating: StarRating(3), finishedAt: new Date('2026-02-01') }),
        book('five', { rating: StarRating(5), finishedAt: new Date('2026-01-01') }),
        book('newer-three', { rating: StarRating(3), finishedAt: new Date('2026-03-01') }),
      ],
      new Map(),
    )

    expect(shelf.map((entry) => String(entry.id))).toEqual(['five', 'newer-three', 'older-three'])
  })

  test('ranks a volume on the rating its saga lends it', () => {
    const shelf = ratedShelfOf(
      [book('three', { rating: StarRating(3) }), book('volume', { series: inSaga })],
      new Map([[kingkiller, StarRating(4)]]),
    )

    expect(shelf.map((entry) => String(entry.id))).toEqual(['volume', 'three'])
  })
})

describe('how far into a recording the reader is', () => {
  const minutes = (value: number) => ListeningMinutes(value)

  test('is the share of the running time the player reached, rounded down', () => {
    expect(
      listeningProgressOf({ durationMinutes: minutes(600), listenedMinutes: minutes(299) }),
    ).toBe(49)
  })

  test('never runs past a hundred', () => {
    expect(
      listeningProgressOf({ durationMinutes: minutes(600), listenedMinutes: minutes(610) }),
    ).toBe(100)
  })

  test('is unknown without a running time or a position', () => {
    expect(listeningProgressOf({ listenedMinutes: minutes(10) })).toBeUndefined()
    expect(listeningProgressOf({ durationMinutes: minutes(600) })).toBeUndefined()
  })
})

describe('placing a book in a saga by hand', () => {
  const thilliez = [AuthorName('Franck Thilliez')]
  const bob = [AuthorName('Dennis E. Taylor')]
  const held = (name: string, author: string, kind: VolumeKind = 'main') => ({
    id: SeriesId(`${slugify(name)}--${slugify(author)}`),
    name: SeriesName(name),
    kind,
  })

  test('keys a new saga the way a scan would, from the name and the first author', () => {
    const placed = membershipFor(
      { name: SeriesName('Sharko et Henebelle'), volume: VolumeNumber(3) },
      thilliez,
      'book',
      undefined,
      [],
    )

    expect(placed).toEqual({
      id: SeriesId('sharko-et-henebelle--franck-thilliez'),
      name: SeriesName('Sharko et Henebelle'),
      volume: VolumeNumber(3),
      kind: 'main',
    })
  })

  // The scan may have filed the other volumes under a misspelled author: the
  // reader is gathering the saga their shelves show, not starting a second one.
  test('joins a saga the reader holds under the same name, whatever its author', () => {
    const shelf = held('Sharko et Henebelle', 'Franck Tillier')

    const placed = membershipFor(
      { name: SeriesName('sharko et hénebelle') },
      thilliez,
      'book',
      undefined,
      [shelf],
    )

    expect(placed).toEqual({ id: shelf.id, name: SeriesName('Sharko et Henebelle'), kind: 'main' })
  })

  test('prefers the saga held under its own key over a namesake by another author', () => {
    const namesake = held('Chronicles', 'Someone Else')
    const own = held('Chronicles', 'Franck Thilliez')

    const placed = membershipFor({ name: SeriesName('Chronicles') }, thilliez, 'book', undefined, [
      namesake,
      own,
    ])

    expect(placed).toMatchObject({ id: own.id })
  })

  test('keeps the volume kind of a book that stays in its saga', () => {
    const prequel = held('Dune', 'Frank Herbert', 'prequel')

    const placed = membershipFor(
      { name: SeriesName('Dune'), volume: VolumeNumber(1) },
      [AuthorName('Frank Herbert')],
      'book',
      prequel,
      [prequel],
    )

    expect(placed).toMatchObject({ id: prequel.id, kind: 'prequel' })
  })

  test('makes a book moved to another saga a main volume', () => {
    const placed = membershipFor(
      { name: SeriesName('Autre') },
      thilliez,
      'book',
      held('Dune', 'Frank Herbert', 'prequel'),
      [],
    )

    expect(placed).toMatchObject({ kind: 'main' })
  })

  test('lets a book with no author join a saga the reader holds', () => {
    const shelf = held('Dune', 'Frank Herbert')

    expect(
      membershipFor({ name: SeriesName('Dune') }, [], 'book', undefined, [shelf]),
    ).toMatchObject({
      id: shelf.id,
    })
  })

  // A saga heard is not the saga read: the recordings trail the books, and the
  // listener's spine is the recorded one.
  test('keys an audiobook to the saga heard', () => {
    const placed = membershipFor({ name: SeriesName('Bobiverse') }, bob, 'audiobook', undefined, [])

    expect(placed).toMatchObject({ id: SeriesId('bobiverse--dennis-e-taylor--audio') })
  })

  test('never joins a namesake saga of the other format', () => {
    const read = held('Bobiverse', 'Dennis Taylor')
    const heard = {
      ...held('Bobiverse', 'Dennis Taylor'),
      id: SeriesId('bobiverse--dennis-taylor--audio'),
    }

    expect(
      membershipFor({ name: SeriesName('Bobiverse') }, bob, 'audiobook', undefined, [read]),
    ).toMatchObject({ id: SeriesId('bobiverse--dennis-e-taylor--audio') })
    expect(
      membershipFor({ name: SeriesName('Bobiverse') }, bob, 'audiobook', undefined, [read, heard]),
    ).toMatchObject({ id: heard.id })
    expect(
      membershipFor({ name: SeriesName('Bobiverse') }, bob, 'book', undefined, [heard]),
    ).toMatchObject({ id: SeriesId('bobiverse--dennis-e-taylor') })
  })

  test('refuses a new saga for a book with no author to key it with', () => {
    expect(membershipFor({ name: SeriesName('Dune') }, [], 'book', undefined, [])).toBe('no-author')
  })
})

describe('a saga in the format of its book', () => {
  const series = {
    id: SeriesId('bobiverse--dennis-e-taylor'),
    name: SeriesName('Bobiverse'),
    volume: VolumeNumber(2),
    kind: 'main' as const,
  }

  test('moves a book turned audiobook to the saga heard, and back', () => {
    const heard = seriesInFormat(series, 'audiobook')
    expect(heard).toEqual({ ...series, id: SeriesId('bobiverse--dennis-e-taylor--audio') })
    expect(seriesInFormat(heard, 'ebook')).toEqual(series)
  })

  test('leaves a standalone book standalone', () => {
    expect(seriesInFormat(undefined, 'audiobook')).toBeUndefined()
  })
})

describe('storedRecommendation', () => {
  test('keeps a recommendation that names someone or says something', () => {
    expect(storedRecommendation({ recommenderName: PersonName('Marie') })).toEqual({
      recommenderName: PersonName('Marie'),
    })
    expect(storedRecommendation({ comment: RecommendationComment('Superbe.') })).toEqual({
      comment: RecommendationComment('Superbe.'),
    })
  })

  test('stores nothing for a recommendation that names nobody and says nothing', () => {
    expect(storedRecommendation({})).toBeUndefined()
    expect(storedRecommendation(undefined)).toBeUndefined()
  })

  // Firestore refuses undefined values: an absent half is left out, not kept
  // as a key with nothing in it.
  test('leaves out the half that is missing', () => {
    const stored = storedRecommendation({
      recommenderName: PersonName('Marie'),
      comment: undefined,
    })
    expect(Object.keys(stored ?? {})).toEqual(['recommenderName'])
  })
})

describe('a saga in the order it runs', () => {
  test('puts the numbered spine first, then what orbits it', () => {
    const ordered = inSagaOrder([
      book({ title: 'Contes', series: { name: 'Terremer', kind: 'novella' } }),
      book({ title: 'Tome 2', series: { name: 'Terremer', volume: 2 } }),
      book({ title: 'Tome 1', series: { name: 'Terremer', volume: 1 } }),
    ])

    expect(ordered.map(({ title }) => String(title))).toEqual(['Tome 1', 'Tome 2', 'Contes'])
  })

  test('treats a volume with no saga as part of the spine', () => {
    expect(inSagaOrder([book({ title: 'Seul' })]).map(({ title }) => String(title))).toEqual([
      'Seul',
    ])
  })
})
