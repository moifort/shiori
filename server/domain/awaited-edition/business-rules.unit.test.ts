import { describe, expect, test } from 'bun:test'
import type { AwaitedEditionView, FoundEdition } from '~/domain/awaited-edition/types'
import type { Book } from '~/domain/book/types'
import type { ReleaseDate } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'
import {
  alertIsDue,
  alertOf,
  awaitableFormatsOf,
  dueWatchesOf,
  editionWatchKeyOf,
  inShelfOrder,
  isConfirmed,
  isHeld,
  stateOf,
  storeUrlOf,
} from './business-rules'
import type { AwaitedEdition, EditionWatch } from './types'

const today = '2026-09-28'
const found = (fields: Partial<FoundEdition> = {}) =>
  ({ title: 'Vent et vérité', ...fields }) as FoundEdition

const awaited = (fields: Partial<AwaitedEdition> = {}): AwaitedEdition =>
  ({
    id: 'reader--wind-and-truth--brandon-sanderson--audiobook--fr',
    userId: 'reader' as UserId,
    format: 'audiobook',
    language: 'fr',
    source: {
      bookId: 'b1',
      ownerId: 'reader',
      title: 'Wind and Truth',
      authors: ['Brandon Sanderson'],
      language: 'en',
    },
    watchKey: 'wind-and-truth--brandon-sanderson--audiobook--fr',
    awaitedAt: new Date('2026-09-01'),
    ...fields,
  }) as AwaitedEdition

const view = (fields: Partial<AwaitedEditionView> = {}): AwaitedEditionView => ({
  ...awaited(),
  state: 'unannounced',
  watched: true,
  ...fields,
})

describe('awaitableFormatsOf', () => {
  test('offers a book in another language translated and recorded', () => {
    expect(awaitableFormatsOf({ language: 'en', format: 'book' }, 'fr')).toEqual([
      'book',
      'audiobook',
    ])
    expect(awaitableFormatsOf({ language: 'en', format: 'audiobook' }, 'fr')).toEqual([
      'book',
      'audiobook',
    ])
  })

  test('offers a printed book in the app’s language recorded, and a recording in it nothing', () => {
    expect(awaitableFormatsOf({ language: 'fr', format: 'book' }, 'fr')).toEqual(['audiobook'])
    expect(awaitableFormatsOf({ language: 'fr', format: 'audiobook' }, 'fr')).toEqual([])
  })

  test('takes a book that names no language to be in the app’s', () => {
    expect(awaitableFormatsOf({ format: 'book' }, 'fr')).toEqual(['audiobook'])
  })
})

describe('editionWatchKeyOf', () => {
  test('folds the title and first author, then the format and language', () => {
    expect(
      editionWatchKeyOf(
        { title: 'The Wind and Truth' as never, authors: ['Brandon Sanderson' as never] },
        'audiobook',
        'fr',
      ),
    ).toBe('wind-and-truth--brandon-sanderson--audiobook--fr')
  })
})

describe('stateOf', () => {
  test('is unannounced until something is found', () => {
    expect(stateOf(undefined, 'book', today)).toBe('unannounced')
  })

  test('is announced for an edition with no date or a date to come', () => {
    expect(stateOf(found(), 'book', today)).toBe('announced')
    expect(stateOf(found({ date: '2027-03' as ReleaseDate }), 'book', today)).toBe('announced')
    expect(stateOf(found({ date: '2026-09' as ReleaseDate }), 'book', today)).toBe('announced')
  })

  test('is available for a printed edition past its date', () => {
    expect(stateOf(found({ date: '2026-09-28' as ReleaseDate }), 'book', today)).toBe('available')
    expect(stateOf(found({ date: '2026-08' as ReleaseDate }), 'book', today)).toBe('available')
  })

  test('is available for a recording past its date, confirmed by Audible or not', () => {
    const out = { date: '2026-09-01' as ReleaseDate }
    expect(stateOf(found(out), 'audiobook', today)).toBe('available')
    expect(stateOf(found({ ...out, asin: 'B0DM67WR2V' as never }), 'audiobook', today)).toBe(
      'available',
    )
    expect(isConfirmed(found(out), 'audiobook')).toBe(false)
    expect(isConfirmed(found({ ...out, asin: 'B0DM67WR2V' as never }), 'audiobook')).toBe(true)
    expect(isConfirmed(found(out), 'book')).toBe(true)
  })
})

describe('isHeld', () => {
  const book = (fields: Partial<Book>) =>
    ({ format: 'audiobook', language: 'fr', title: 'Autre', authors: ['X'], ...fields }) as Book

  test('holds the recording found, by its ASIN', () => {
    const edition = found({ asin: 'B0DM67WR2V' as never })
    expect(isHeld(awaited(), edition, [book({ audibleAsin: 'B0DM67WR2V' as never })])).toBe(true)
  })

  test('holds a book of its format and language bearing its title and author', () => {
    const books = [
      book({ title: 'Vent et vérité' as never, authors: ['Brandon Sanderson' as never] }),
    ]
    expect(isHeld(awaited(), found(), books)).toBe(true)
  })

  test('does not hold it in another format, or before anything is found', () => {
    const books = [
      book({
        format: 'book',
        title: 'Vent et vérité' as never,
        authors: ['Brandon Sanderson' as never],
      }),
    ]
    expect(isHeld(awaited(), found(), books)).toBe(false)
    expect(isHeld(awaited(), undefined, books)).toBe(false)
  })
})

describe('dueWatchesOf', () => {
  const now = new Date('2026-09-28T08:00:00Z')
  const watch = (fields: Partial<EditionWatch>): EditionWatch =>
    ({ key: awaited().watchKey, format: 'audiobook', checkedAt: now, ...fields }) as EditionWatch

  test('looks each watch up once, the ones never looked up first', () => {
    const other = awaited({ id: 'o' as never, watchKey: 'other' })
    const watches = new Map([[awaited().watchKey, watch({ checkedAt: new Date('2026-09-01') })]])
    expect(
      dueWatchesOf([awaited(), awaited({ userId: 'b' as UserId }), other], watches, now, today).map(
        (edition) => edition.watchKey,
      ),
    ).toEqual(['other', awaited().watchKey])
  })

  test('leaves a watch less than two weeks old, and one found out', () => {
    const fresh = new Map([[awaited().watchKey, watch({})]])
    expect(dueWatchesOf([awaited()], fresh, now, today)).toEqual([])
    const out = new Map([
      [
        awaited().watchKey,
        watch({
          checkedAt: new Date('2026-09-01'),
          found: found({ date: '2026-09-01' as ReleaseDate, asin: 'B0DM67WR2V' as never }),
        }),
      ],
    ])
    expect(dueWatchesOf([awaited()], out, now, today)).toEqual([])
  })

  test('keeps looking up a recording out that Audible never confirmed', () => {
    const unconfirmed = new Map([
      [
        awaited().watchKey,
        watch({
          checkedAt: new Date('2026-09-01'),
          found: found({ date: '2026-09-01' as ReleaseDate }),
        }),
      ],
    ])
    expect(dueWatchesOf([awaited()], unconfirmed, now, today)).toHaveLength(1)
  })
})

describe('alerts', () => {
  const out = (date: string) =>
    view({
      state: 'available',
      found: found({ date: date as ReleaseDate, asin: 'B0DM67WR2V' as never }),
    })

  test('are due for an edition out in the last three weeks, never sent', () => {
    expect(alertIsDue(out('2026-09-28'), today)).toBe(true)
    expect(alertIsDue(out('2026-09-01'), today)).toBe(false)
    expect(alertIsDue({ ...out('2026-09-28'), notifiedAt: new Date() }, today)).toBe(false)
    expect(alertIsDue(view({ state: 'announced' }), today)).toBe(false)
  })

  test('are never sent for a recording Audible did not confirm', () => {
    const unconfirmed = view({
      state: 'available',
      found: found({ date: '2026-09-28' as ReleaseDate }),
    })
    expect(alertIsDue(unconfirmed, today)).toBe(false)
  })

  test('name the edition in the reader’s language', () => {
    expect(alertOf(out('2026-09-28'), 'fr')).toEqual({
      title: 'Sorti en audio',
      body: '« Vent et vérité » de Brandon Sanderson est sorti en livre audio.',
    })
    expect(alertOf({ ...out('2026-09-28'), format: 'book' }, 'en')).toEqual({
      title: 'Out in English',
      body: '"Vent et vérité" by Brandon Sanderson is out.',
    })
  })
})

describe('inShelfOrder', () => {
  test('draws the editions out first, then the announced soonest first, then the rest', () => {
    const at = (day: string) => new Date(day)
    const views = [
      view({ id: 'late' as never, awaitedAt: at('2026-09-01') }),
      view({ id: 'undated' as never, state: 'announced', found: found() }),
      view({
        id: 'march' as never,
        state: 'announced',
        found: found({ date: '2027-03' as ReleaseDate }),
      }),
      view({ id: 'recent' as never, awaitedAt: at('2026-09-20') }),
      view({
        id: 'out' as never,
        state: 'available',
        found: found({ date: '2026-09-02' as ReleaseDate }),
      }),
      view({
        id: 'january' as never,
        state: 'announced',
        found: found({ date: '2027-01-10' as ReleaseDate }),
      }),
    ]
    expect(inShelfOrder(views).map((edition) => edition.id)).toEqual([
      'out',
      'january',
      'march',
      'undated',
      'recent',
      'late',
    ] as never[])
  })
})

describe('inShelfOrder, for the strip', () => {
  test('draws an edition awaited in the last two days first, whatever it stands at', () => {
    const now = new Date('2026-10-08T20:00:00Z')
    const views = [
      view({ id: 'out' as never, state: 'available', awaitedAt: new Date('2026-09-01') }),
      view({
        id: 'just' as never,
        state: 'unannounced',
        awaitedAt: new Date('2026-10-08T19:00:00Z'),
      }),
      view({ id: 'yesterday' as never, awaitedAt: new Date('2026-10-07T21:00:00Z') }),
      view({ id: 'old' as never, awaitedAt: new Date('2026-10-05') }),
    ]
    expect(inShelfOrder(views, now).map((edition) => edition.id)).toEqual([
      'just',
      'yesterday',
      'out',
      'old',
    ] as never[])
    expect(inShelfOrder(views).map((edition) => edition.id)[0]).toBe('out' as never)
  })
})

describe('storeUrlOf', () => {
  test('points a recording to its page on the language’s Audible store', () => {
    expect(storeUrlOf('audiobook', 'fr', { asin: 'B0DM67WR2V' as never })).toBe(
      'https://www.audible.fr/pd/B0DM67WR2V',
    )
    expect(storeUrlOf('audiobook', 'fr', { title: 'Vent et vérité' }, 'Brandon Sanderson')).toBe(
      'https://www.audible.fr/search?keywords=Vent%20et%20v%C3%A9rit%C3%A9%20Brandon%20Sanderson',
    )
  })

  test('points a printed edition to Amazon by the ISBN-10 it is filed under', () => {
    expect(storeUrlOf('book', 'fr', { isbn13: '9782226488176' as never })).toBe(
      'https://www.amazon.fr/dp/2226488170',
    )
  })
})
