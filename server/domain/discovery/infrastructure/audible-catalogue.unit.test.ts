import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { AudibleAsin } from '~/domain/audible/primitives'
import {
  audibleEditionOf,
  audibleProductOf,
} from '~/domain/discovery/infrastructure/audible-catalogue'

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
type Store = { products?: Record<string, unknown>; search?: unknown[] }

const storesAnswer = (stores: { fr: Store; us?: Store; uk?: Store }) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    asked.push(url)
    const store = url.includes('api.audible.fr')
      ? stores.fr
      : url.includes('api.audible.co.uk')
        ? (stores.uk ?? {})
        : (stores.us ?? {})
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

  // We Are Legion is B01L0831K6 on audible.co.uk and B01L082HJ2 on audible.com.
  test('swaps a British ASIN for the same recording on audible.com', async () => {
    const bob = (asin: string) => ({
      asin,
      title: 'We Are Legion (We Are Bob)',
      language: 'english',
      release_date: '2016-09-20',
      authors: [{ name: 'Dennis E. Taylor' }],
    })
    storesAnswer({
      fr: {},
      uk: { products: { B01L0831K6: bob('B01L0831K6') } },
      us: { search: [bob('B01L082HJ2')] },
    })

    const product = await audibleProductOf(AudibleAsin('B01L0831K6'), 'en')

    expect(product).toMatchObject({ asin: 'B01L082HJ2', releaseDate: '2016-09-20' })
  })

  // A model often names the Kindle ASIN of a recording: Heretical Fishing 3 is
  // B0D7X6LPGP on Kindle and B0D7XD7PTN on Audible.
  test('finds the recording by its exact title when no store knows the ASIN', async () => {
    const title = 'Heretical Fishing 3: A Cozy Guide to Annoying the Cults'
    storesAnswer({
      fr: {},
      us: {
        search: [
          {
            asin: 'B0CZPKBY63',
            title: 'Heretical Fishing 2: A Cozy Guide to Annoying the Cults',
            language: 'english',
          },
          { asin: 'B0D7XD7PTN', title, language: 'english', release_date: '2024-11-12' },
        ],
      },
    })

    const product = await audibleProductOf(AudibleAsin('B0D7X6LPGP'), 'en', title)

    expect(product).toMatchObject({ asin: 'B0D7XD7PTN', releaseDate: '2024-11-12' })
  })

  test('stays unknown when several recordings carry that exact title', async () => {
    const title = 'Dune'
    storesAnswer({
      fr: {},
      us: {
        search: [
          { asin: 'B002V1OF70', title, language: 'english' },
          { asin: 'B0CQ8DMJ9P', title, language: 'english' },
        ],
      },
    })

    expect(await audibleProductOf(AudibleAsin('B0KINDLE01'), 'en', title)).toBe('unknown')
  })
})

describe('audibleEditionOf', () => {
  test('finds the recording of a book by its title and author, in its language', async () => {
    const asked = storesAnswer({
      fr: {
        search: [
          neuromancien('B0STUDY', { title: 'Neuromancien : une étude' }),
          neuromancien(FR_ASIN, {
            narrators: [{ name: 'Nicolas Planchais' }],
            runtime_length_min: 612,
          }),
        ],
      },
    })

    const recording = await audibleEditionOf('Neuromancien', 'William Gibson', 'fr')

    expect(recording).toMatchObject({ title: 'Neuromancien', narrators: ['Nicolas Planchais'] })
    expect(recording).toMatchObject({ durationMinutes: 612 })
    expect(asked[0]).toContain('api.audible.fr')
  })

  // A namesake, or the same title recorded in another language, is not it.
  test('answers unknown when no recording carries that title, author and language', async () => {
    storesAnswer({
      fr: {
        search: [
          neuromancien('B01', { authors: [{ name: 'Someone Else' }] }),
          neuromancien('B02', { language: 'english' }),
        ],
      },
    })

    expect(await audibleEditionOf('Neuromancien', 'William Gibson', 'fr')).toBe('unknown')
  })

  test('answers unreachable when Audible cannot be asked', async () => {
    spyOn(globalThis, 'fetch').mockImplementation(
      (async () => new Response('', { status: 503 })) as unknown as typeof fetch,
    )

    expect(await audibleEditionOf('Neuromancien', 'William Gibson', 'fr')).toBe('unreachable')
  })
})
