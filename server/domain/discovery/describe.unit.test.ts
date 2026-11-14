import { describe, expect, test } from 'bun:test'
import {
  DESCRIPTION_KEPT_DAYS,
  isDescriptionFresh,
  releaseDescriptionKeyOf,
} from '~/domain/discovery/business-rules'

const seed = {
  title: 'Carl 4',
  authors: ['Matt Dinniman'],
  format: 'book',
  language: 'fr',
} as never

describe('releaseDescriptionKeyOf', () => {
  test('folds the title and the author, so two readers converge on one description', () => {
    const typed = { ...(seed as object), title: 'CARL  4', authors: ['matt dinniman'] } as never
    expect(releaseDescriptionKeyOf(typed, 'fr')).toBe(releaseDescriptionKeyOf(seed, 'fr'))
  })

  test('tells apart the recording, the edition, the volume and the language written in', () => {
    const key = releaseDescriptionKeyOf(seed, 'fr')
    const variants = [
      { ...(seed as object), format: 'audiobook' },
      { ...(seed as object), language: 'en' },
      { ...(seed as object), series: { id: 's', name: 'Carl', kind: 'main', volume: 5 } },
    ] as never[]
    for (const variant of variants) expect(releaseDescriptionKeyOf(variant, 'fr')).not.toBe(key)
    expect(releaseDescriptionKeyOf(seed, 'en')).not.toBe(key)
  })
})

describe('isDescriptionFresh', () => {
  const day = 86_400_000
  const describedAt = new Date('2026-03-10T12:00:00Z')
  const kept = { key: 'k', description: {} as never, describedAt }
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
