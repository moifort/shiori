import { describe, expect, test } from 'bun:test'
import { releaseDescriptionKeyOf } from '~/domain/discovery/business-rules'

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
