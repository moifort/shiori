import { describe, expect, test } from 'bun:test'
import type { AudibleItem } from 'audible-api-ts'
import { listenedSagasOf, nextInSaga } from '~/domain/audible/business-rules'

const item = (fields: Partial<AudibleItem>): AudibleItem =>
  ({
    asin: 'B000000000',
    title: 'Untitled',
    authors: ['Will Wight'],
    narrators: [],
    durationMinutes: 600,
    categories: [{ root: 'Genres', categories: [{ id: 'fantasy-shelf', name: 'Fantasy' }] }],
    keywords: [],
    relationships: [],
    isAdultProduct: false,
    productImages: {},
    socialMediaImages: {},
    ...fields,
  }) as AudibleItem

describe('the sagas an Audible library holds', () => {
  const owned = [
    item({
      asin: 'B000000001',
      series: { name: 'Cradle', position: 1 },
      purchaseDate: new Date('2025-01-01'),
    }),
    item({
      asin: 'B000000002',
      series: { name: 'Cradle', position: 11 },
      purchaseDate: new Date('2026-06-01'),
    }),
    item({
      asin: 'B000000003',
      series: { name: 'The Legend of Drizzt' },
      purchaseDate: new Date('2024-01-01'),
      releaseDate: new Date('2020-01-01'),
    }),
  ]

  test('know how far the reader is, the saga bought last first', () => {
    const sagas = listenedSagasOf(owned)
    expect(sagas.map((saga) => [saga.name, saga.lastPosition])).toEqual([
      ['Cradle', 11],
      ['The Legend of Drizzt', undefined],
    ])
    expect(sagas[0]?.categoryId).toBe('fantasy-shelf')
  })

  test('propose the volumes past the last one owned, preorders included', () => {
    const [cradle] = listenedSagasOf(owned)
    if (!cradle) throw new Error('no saga')
    const found = [
      item({ asin: 'B000000002', series: { name: 'Cradle', position: 11 } }),
      item({ asin: 'B000000012', series: { name: 'Cradle', position: 12 } }),
      item({
        asin: 'B000000013',
        series: { name: 'Cradle', position: 13 },
        releaseDate: new Date('2027-01-01'),
      }),
      item({ asin: 'B000000099', series: { name: 'Cradle: Side Stories', position: 2 } }),
    ]
    expect(nextInSaga(cradle, found, new Set(owned.map((i) => i.asin))).map((i) => i.asin)).toEqual(
      ['B000000012', 'B000000013'],
    )
  })

  test('fall back on release dates for a saga Audible does not number', () => {
    const drizzt = listenedSagasOf(owned)[1]
    if (!drizzt) throw new Error('no saga')
    const found = [
      item({
        asin: 'B000000031',
        series: { name: 'The Legend of Drizzt' },
        releaseDate: new Date('2019-01-01'),
      }),
      item({
        asin: 'B000000032',
        series: { name: 'The Legend of Drizzt' },
        releaseDate: new Date('2026-10-01'),
      }),
    ]
    expect(nextInSaga(drizzt, found, new Set()).map((i) => i.asin)).toEqual(['B000000032'])
  })
})
