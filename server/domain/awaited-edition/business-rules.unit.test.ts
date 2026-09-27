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
  test('offers a book in another language translated, and recorded to a listener', () => {
    expect(awaitableFormatsOf({ language: 'en', format: 'book' }, 'fr', true)).toEqual([
      'book',
      'audiobook',
    ])
  })

  test('offers no recording to a reader who never listens', () => {
    expect(awaitableFormatsOf({ language: 'en', format: 'audiobook' }, 'fr', false)).toEqual([
      'book',
    ])
  })

  test('offers nothing for a book in the app’s language, nor one in no language known', () => {
    expect(awaitableFormatsOf({ language: 'fr', format: 'book' }, 'fr', true)).toEqual([])
    expect(awaitableFormatsOf({ format: 'book' }, 'fr', true)).toEqual([])
  })

  test('offers a printed book in the app’s language recorded once Audible lacks it', () => {
    expect(awaitableFormatsOf({ language: 'fr', format: 'book' }, 'fr', true, true)).toEqual([
      'audiobook',
    ])
    expect(awaitableFormatsOf({ language: 'fr', format: 'book' }, 'fr', false, true)).toEqual([])
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

  test('is available for a recording only once Audible confirmed it', () => {
    const out = { date: '2026-09-01' as ReleaseDate }
    expect(stateOf(found(out), 'audiobook', today)).toBe('announced')
    expect(stateOf(found({ ...out, asin: 'B0DM67WR2V' as never }), 'audiobook', today)).toBe(
      'available',
    )
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

  test('leaves a watch less than a week old, and one found out', () => {
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
})

describe('alerts', () => {
  const out = (date: string) =>
    view({ state: 'available', found: found({ date: date as ReleaseDate }) })

  test('are due for an edition out in the last two weeks, never sent', () => {
    expect(alertIsDue(out('2026-09-28'), today)).toBe(true)
    expect(alertIsDue(out('2026-09-01'), today)).toBe(false)
    expect(alertIsDue({ ...out('2026-09-28'), notifiedAt: new Date() }, today)).toBe(false)
    expect(alertIsDue(view({ state: 'announced' }), today)).toBe(false)
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

describe('storeUrlOf', () => {
  test('points a recording to its page on the language’s Audible store', () => {
    expect(storeUrlOf('audiobook', 'fr', { asin: 'B0DM67WR2V' as never })).toBe(
      'https://www.audible.fr/pd/B0DM67WR2V',
    )
    expect(storeUrlOf('audiobook', 'fr', {})).toBeUndefined()
  })

  test('points a printed edition to Amazon by the ISBN-10 it is filed under', () => {
    expect(storeUrlOf('book', 'fr', { isbn13: '9782226488176' as never })).toBe(
      'https://www.amazon.fr/dp/2226488170',
    )
  })
})
