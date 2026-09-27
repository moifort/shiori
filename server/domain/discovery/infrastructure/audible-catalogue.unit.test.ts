import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { AudibleAsin } from '~/domain/audible/primitives'
import { audibleProductOf } from '~/domain/discovery/infrastructure/audible-catalogue'

const US_ASIN = AudibleAsin('B09VY3W1FF')
const FR_ASIN = 'B09VY5GXM7'

const neuromancien = (asin: string, extra: Record<string, unknown> = {}) => ({
  asin,
  title: 'Neuromancien',
  language: 'french',
  release_date: '2022-04-27',
  authors: [{ name: 'William Gibson' }],
  ...extra,
})

/** Answers each Audible store from its own table: a product lookup by the ASIN
 *  after `products/`, a search from `products?`. Records every URL asked. */
const storesAnswer = (stores: {
  fr: { products?: Record<string, unknown>; search?: unknown[] }
  us?: { products?: Record<string, unknown> }
}) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    asked.push(url)
    const store = url.includes('api.audible.fr') ? stores.fr : (stores.us ?? {})
    if (url.includes('/catalog/products?')) {
      return Response.json({ products: 'search' in store ? (store.search ?? []) : [] })
    }
    const asin = url.split('/catalog/products/')[1]?.split('?')[0] ?? ''
    return Response.json({ product: store.products?.[asin] ?? { asin } })
  }) as unknown as typeof fetch)
  return asked
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('audibleProductOf', () => {
  test('confirms an ASIN the store of that language sells', async () => {
    storesAnswer({ fr: { products: { [US_ASIN]: neuromancien(US_ASIN) } } })

    const product = await audibleProductOf(US_ASIN, 'fr')

    expect(product).toMatchObject({ asin: US_ASIN, releaseDate: '2022-04-27' })
  })

  test('swaps an ASIN from another store for the same recording in the reader’s', async () => {
    storesAnswer({
      fr: {
        search: [neuromancien('B00BS9S7AC', { release_date: '2013-03-18' }), neuromancien(FR_ASIN)],
      },
      us: { products: { [US_ASIN]: neuromancien(US_ASIN) } },
    })

    const product = await audibleProductOf(US_ASIN, 'fr')

    expect(product).toMatchObject({ asin: FR_ASIN, releaseDate: '2022-04-27' })
  })

  test('stays unknown when the reader’s store has no recording released that day', async () => {
    storesAnswer({
      fr: { search: [neuromancien('B00BS9S7AC', { release_date: '2013-03-18' })] },
      us: { products: { [US_ASIN]: neuromancien(US_ASIN) } },
    })

    expect(await audibleProductOf(US_ASIN, 'fr')).toBe('unknown')
  })

  test('stays unknown when no store knows the ASIN, without searching', async () => {
    const asked = storesAnswer({ fr: {} })

    expect(await audibleProductOf(US_ASIN, 'fr')).toBe('unknown')
    expect(asked.some((url) => url.includes('/catalog/products?'))).toBe(false)
  })

  test('asks no other store for a language sold on audible.com', async () => {
    const asked = storesAnswer({ fr: {} })

    expect(await audibleProductOf(US_ASIN, 'en')).toBe('unknown')
    expect(asked).toHaveLength(1)
  })
})
