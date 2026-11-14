import { describe, expect, test } from 'bun:test'
import type { ReleaseDescription } from '~/domain/discovery/types'
import {
  DESCRIPTION_KEPT_DAYS,
  describedFromOf,
  isDescriptionFresh,
  keptDescriptionOf,
  releaseKeyOf,
  releaseViewOf,
} from '~/domain/release/business-rules'
import type { KeptDescription, ReleaseShown } from '~/domain/release/types'

const now = new Date('2026-11-14T08:00:00Z')
const DAY = 86_400_000

const description = {
  book: {
    recognized: true,
    title: 'La ragazza nella nebbia',
    authors: ['Donato Carrisi'],
    synopsis: 'Une adolescente disparaît.',
    pageCount: 380,
    isbn13: '9788830443829',
    coverUrl: 'https://covers.example/described.jpg',
    publisher: 'Longanesi',
    subgenres: ['Giallo'],
  },
  narrators: ['Alberto Angrisano'],
  durationMinutes: 455,
} as unknown as ReleaseDescription

const kept = (describedAt = now, describedFrom = 'ragazza-nella-nebbia~it'): KeptDescription => ({
  description,
  describedAt,
  describedFrom,
})

const shown = (overrides: Partial<ReleaseShown> = {}): ReleaseShown =>
  ({
    key: 'ragazza-nella-nebbia--donato-carrisi--audiobook--fr',
    seed: {
      title: 'La ragazza nella nebbia',
      authors: ['Donato Carrisi'],
      format: 'audiobook',
      language: 'it',
    },
    originalTitle: 'La ragazza nella nebbia',
    originalLanguage: 'it',
    language: 'fr',
    releaseFormat: 'audiobook',
    state: 'unannounced',
    watched: true,
    ...overrides,
  }) as ReleaseShown

describe('releaseKeyOf', () => {
  test('folds the title and the author, so every list converges on one release', () => {
    expect(releaseKeyOf('La Ragazza  nella nebbia', 'donato carrisi', 'audiobook', 'fr')).toBe(
      releaseKeyOf('La ragazza nella nebbia', 'Donato Carrisi', 'audiobook', 'fr'),
    )
  })

  test('tells the recording and the edition apart', () => {
    const key = releaseKeyOf('Silo', 'Hugh Howey', 'book', 'fr')
    expect(releaseKeyOf('Silo', 'Hugh Howey', 'audiobook', 'fr')).not.toBe(key)
    expect(releaseKeyOf('Silo', 'Hugh Howey', 'book', 'en')).not.toBe(key)
  })
})

describe('keptDescriptionOf', () => {
  const release = { descriptions: { fr: kept() } }

  test('answers the description of the book shown, in the app’s language', () => {
    expect(
      keptDescriptionOf(
        release,
        { title: 'La ragazza nella nebbia', language: 'it' } as never,
        'fr',
      ),
    ).toEqual(kept())
    expect(
      keptDescriptionOf(
        release,
        { title: 'La ragazza nella nebbia', language: 'it' } as never,
        'en',
      ),
    ).toBeUndefined()
  })

  test('drops the original’s once the edition is found under its own title', () => {
    expect(
      keptDescriptionOf(release, { title: 'La fille dans le brouillard' } as never, 'fr'),
    ).toBeUndefined()
    expect(describedFromOf({ title: 'La fille dans le brouillard' } as never)).toBe(
      'fille-dans-le-brouillard~-',
    )
  })
})

describe('releaseViewOf', () => {
  test('completes the book shown with its description, kept the book shown', () => {
    const view = releaseViewOf(shown(), { descriptions: { fr: kept() } }, 'fr', now)
    expect(view).toMatchObject({
      title: 'La ragazza nella nebbia',
      authors: ['Donato Carrisi'],
      synopsis: 'Une adolescente disparaît.',
      publisher: 'Longanesi',
      narrators: ['Alberto Angrisano'],
      durationMinutes: 455,
      describedCoverUrl: 'https://covers.example/described.jpg',
      described: true,
    })
  })

  test('says the language of the book shown, the original’s while nothing is announced', () => {
    const view = releaseViewOf(shown(), undefined, 'fr', now)
    expect(view.language).toBe('it' as never)
    expect(view.editionLanguage).toBe('fr' as never)
  })

  test('gives a recording no pages, nor the ISBN of the print', () => {
    const view = releaseViewOf(shown(), { descriptions: { fr: kept() } }, 'fr', now)
    expect(view.pageCount).toBeUndefined()
    expect(view.isbn13).toBeUndefined()
  })

  test('draws the edition’s cover first, then the book shown’s, then the description’s', () => {
    const found = { title: 'X', coverUrl: 'https://covers.example/found.jpg' }
    const withSeed = shown({ seed: { ...shown().seed, coverUrl: 'https://c/seed.jpg' } as never })
    expect(releaseViewOf(shown({ found } as never), undefined, 'fr', now).coverUrl).toBe(
      'https://covers.example/found.jpg' as never,
    )
    expect(releaseViewOf(withSeed, undefined, 'fr', now).coverUrl).toBe(
      'https://c/seed.jpg' as never,
    )
  })

  test('still draws a stale description, and says it is to be asked again', () => {
    const stale = kept(new Date(now.getTime() - 61 * DAY))
    const view = releaseViewOf(shown(), { descriptions: { fr: stale } }, 'fr', now)
    expect(view.synopsis).toBe('Une adolescente disparaît.' as never)
    expect(view.described).toBe(false)
  })

  test('is not described without a description of the book shown', () => {
    expect(releaseViewOf(shown(), undefined, 'fr', now)).toMatchObject({
      described: false,
      narrators: [],
      subgenres: [],
    })
  })
})

describe('isDescriptionFresh', () => {
  const day = 86_400_000
  const describedAt = new Date('2026-03-10T12:00:00Z')
  const kept = { describedAt }
  const later = new Date(describedAt.getTime() + (DESCRIPTION_KEPT_DAYS + 1) * day)

  test('keeps a description made after the book came out for good', () => {
    expect(isDescriptionFresh(kept, later, '2026-03-09' as never)).toBe(true)
    expect(isDescriptionFresh(kept, later, '2025' as never)).toBe(true)
  })

  test('asks again for one made before the book was out, once it is old', () => {
    expect(isDescriptionFresh(kept, later, '2026-03-20' as never)).toBe(false)
    expect(
      isDescriptionFresh(kept, new Date(describedAt.getTime() + day), '2026-03-20' as never),
    ).toBe(true)
  })

  test('counts a month or a year from its last day, and a book out that very day as not yet out', () => {
    expect(isDescriptionFresh(kept, later, '2026-03' as never)).toBe(false)
    expect(isDescriptionFresh(kept, later, '2026' as never)).toBe(false)
    expect(isDescriptionFresh(kept, later, '2026-03-10' as never)).toBe(false)
  })

  test('keeps the sixty days for a book with no date', () => {
    expect(isDescriptionFresh(kept, later)).toBe(false)
    expect(isDescriptionFresh(kept, new Date(describedAt.getTime() + day))).toBe(true)
  })
})
