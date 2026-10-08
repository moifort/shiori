import { describe, expect, test } from 'bun:test'
import type { EditionWatch } from '~/domain/awaited-edition/types'
import type { Book } from '~/domain/book/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import {
  AWARDS_BY_GENRE,
  genresOf,
  hasRead,
  isDue,
  isHeld,
  watchKeyOf,
  worksOf,
} from './business-rules'
import { AWARDS } from './types'
import { WINNERS } from './winners'

type Read = Pick<Book, 'genre' | 'status' | 'rating' | 'finishedAt' | 'statusChangedAt'>
const read = (genre: Book['genre'], extra: Partial<Read> = {}): Read => ({
  genre,
  status: 'read',
  ...extra,
})

describe('the winners', () => {
  test('every award lists one winner per year at most twice, in order', () => {
    for (const award of AWARDS) {
      const years = WINNERS[award].map(([year]) => year)
      expect(years).toEqual([...years].sort((left, right) => left - right))
      for (const year of new Set(years))
        expect(years.filter((other) => other === year).length).toBeLessThanOrEqual(2)
    }
  })

  test('a novel crowned by two awards is one work with both mentions, newest first', () => {
    const dune = worksOf(['hugo', 'nebula']).find((work) => work.title === 'Dune')
    expect(dune?.mentions).toEqual([
      { award: 'hugo', year: 1966 },
      { award: 'nebula', year: 1966 },
    ])
    expect(dune?.key).toBe('dune--frank-herbert')
  })

  test('works come newest first, co-authors apart', () => {
    const works = worksOf(['hugo'])
    expect(works[0]?.title).toBe(BookTitle('The Everlasting'))
    const clifton = works.find((work) => work.title === "They'd Rather Be Right")
    expect(clifton?.authors).toEqual([AuthorName('Mark Clifton'), AuthorName('Frank Riley')])
  })

  test('every genre with awards names only known awards', () => {
    for (const awards of Object.values(AWARDS_BY_GENRE))
      for (const award of awards ?? []) expect(AWARDS).toContain(award)
  })
})

describe('the reader’s genre', () => {
  test('is the genre with awards read most, a well-rated book counting twice', () => {
    const books = [
      read('fantasy'),
      read('fantasy'),
      read('fantasy'),
      read('science-fiction', { rating: 5 as Book['rating'] }),
      read('science-fiction', { rating: 4 as Book['rating'] }),
      read('thriller'),
      read('thriller'),
      read('thriller'),
      read('thriller'),
    ]
    expect(genresOf(books as Book[])).toEqual(['science-fiction', 'fantasy'])
  })

  test('counts the books read or being read, never the pile', () => {
    const books = [
      read('fantasy', { status: 'to-read' }),
      read('fantasy', { status: 'dropped' }),
      read('fantasy', { status: 'reading' }),
      read('fantasy'),
    ]
    expect(genresOf(books as Book[])).toEqual([])
  })

  test('breaks a tie on the genre read most recently', () => {
    const books = [
      ...[1, 2, 3].map(() => read('fantasy', { finishedAt: new Date('2026-01-01') })),
      ...[1, 2, 3].map(() => read('science-fiction', { finishedAt: new Date('2026-05-01') })),
    ]
    expect(genresOf(books as Book[])).toEqual(['science-fiction', 'fantasy'])
  })
})

const hyperion = worksOf(['hugo']).find((work) => work.title === 'Hyperion')
if (!hyperion) throw new Error('Hyperion won the 1990 Hugo')
const found = { title: BookTitle("Les Cantos d'Hypérion"), isbn13: '9782266111560' as never }
const shelved = (title: string, extra: Partial<Book> = {}) =>
  ({
    title: BookTitle(title),
    authors: [AuthorName('Dan Simmons')],
    format: 'book',
    status: 'to-read',
    ...extra,
  }) as Book

describe('what the reader holds', () => {
  test('a French copy is the work, by the title found', () => {
    expect(isHeld(hyperion, 'book', found, [shelved("Les Cantos d'Hypérion")])).toBe(true)
  })

  test('the English title is the work too, and the ISBN found', () => {
    expect(isHeld(hyperion, 'book', undefined, [shelved('Hyperion')])).toBe(true)
    expect(isHeld(hyperion, 'book', found, [shelved('Autre', { isbn13: found.isbn13 })])).toBe(true)
  })

  test('a French copy is not recognised before the edition is found', () => {
    expect(isHeld(hyperion, 'book', undefined, [shelved("Les Cantos d'Hypérion")])).toBe(false)
  })

  test('a printed copy does not hold the recording', () => {
    expect(isHeld(hyperion, 'audiobook', found, [shelved("Les Cantos d'Hypérion")])).toBe(false)
  })

  test('read counts in any format, and only once read', () => {
    expect(
      hasRead(hyperion, found, [shelved("Les Cantos d'Hypérion", { format: 'audiobook' })]),
    ).toBe(false)
    expect(
      hasRead(hyperion, found, [
        shelved("Les Cantos d'Hypérion", { format: 'audiobook', status: 'read' }),
      ]),
    ).toBe(true)
  })
})

describe('when a winner is looked up again', () => {
  const now = new Date('2026-10-08T00:00:00Z')
  const today = '2026-10-08'
  const days = (count: number) => new Date(now.getTime() - count * 86_400_000)
  const watch = (checkedAt: Date, found?: EditionWatch['found']): EditionWatch => ({
    key: watchKeyOf(hyperion, 'book', 'fr'),
    title: hyperion.title,
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt,
    ...(found ? { found } : {}),
  })

  test('never looked up: at once', () => {
    expect(isDue(undefined, now, today)).toBe(true)
  })

  test('out: never again', () => {
    expect(
      isDue(watch(days(400), { title: found.title, date: '1991-01-01' as never }), now, today),
    ).toBe(false)
  })

  test('announced: after two weeks', () => {
    const announced = { title: found.title, date: '2027-01-01' as never }
    expect(isDue(watch(days(13), announced), now, today)).toBe(false)
    expect(isDue(watch(days(14), announced), now, today)).toBe(true)
  })

  test('not found: after two months', () => {
    expect(isDue(watch(days(59)), now, today)).toBe(false)
    expect(isDue(watch(days(60)), now, today)).toBe(true)
  })

  test('shares the key an edition awaited from a scan uses', () => {
    expect(watchKeyOf(hyperion, 'book', 'fr')).toBe('hyperion--dan-simmons--book--fr')
  })
})
