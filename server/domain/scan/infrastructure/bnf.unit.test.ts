import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
import { bnfEditionsOf, editionsIn, isbn13Of, pagesIn } from '~/domain/scan/infrastructure/bnf'
import * as dnsOverHttps from '~/utils/dns-over-https'

const field = (tag: string, subfields: Record<string, string>) =>
  `<mxc:datafield tag="${tag}" ind1=" " ind2=" ">${Object.entries(subfields)
    .map(([code, value]) => `<mxc:subfield code="${code}">${value}</mxc:subfield>`)
    .join('')}</mxc:datafield>`

const record = (...fields: string[]) =>
  `<srw:record><srw:recordData><mxc:record format="Unimarc" type="Bibliographic">${fields.join('')}</mxc:record></srw:recordData></srw:record>`

const answer = (...records: string[]) =>
  `<?xml version="1.0"?><srw:searchRetrieveResponse><srw:records>${records.join('')}</srw:records></srw:searchRetrieveResponse>`

describe('reading BnF records', () => {
  test('reads an edition: ISBN, publisher, year, pages, collection, blurb', () => {
    const editions = editionsIn(
      answer(
        record(
          field('010', { a: '978-2-07-282204-9', b: 'br.', d: '12 EUR' }),
          field('200', { a: 'La horde du contrevent', b: 'Texte imprimé', f: 'Alain Damasio' }),
          field('214', { a: '[Paris]', c: 'Gallimard', d: 'DL 2018' }),
          field('215', { a: '1 vol. (700 p.)', d: '18 cm' }),
          field('225', { a: 'Folio', i: 'Science-fiction', v: '588' }),
          field('330', { a: 'Une Horde remonte le vent jusqu&apos;à sa source.' }),
        ),
      ),
    )

    expect(editions).toEqual([
      {
        isbn13: '9782072822049',
        title: 'La horde du contrevent',
        publisher: 'Gallimard',
        year: '2018',
        pageCount: 700,
        collection: 'Folio',
        summary: "Une Horde remonte le vent jusqu'à sa source.",
      },
    ] as never)
  })

  // A Folio's number is its rank in the collection, not a volume of a saga.
  test('takes the volume from the title or the set, never from the collection', () => {
    const [volume] = editionsIn(
      answer(
        record(
          field('010', { a: '978-2-7234-6060-6' }),
          field('200', { a: 'One Piece', b: 'Texte imprimé', h: '42' }),
          field('225', { a: 'Shonen', v: '7' }),
          field('461', { t: 'One piece', v: '42' }),
        ),
      ),
    )

    expect(volume?.volume).toBe('42')
  })

  test('falls back on the older publication field', () => {
    const [edition] = editionsIn(
      answer(
        record(
          field('010', { a: '2-9522217-0-7' }),
          field('200', { a: 'La horde du contrevent' }),
          field('210', { a: '[Clamart]', c: 'la Volte', d: 'impr. 2004' }),
        ),
      ),
    )

    expect(edition).toMatchObject({ isbn13: '9782952221702', publisher: 'la Volte', year: '2004' })
  })

  test('leaves out recordings and records without an ISBN', () => {
    const editions = editionsIn(
      answer(
        record(
          field('010', { a: '978-2-9522217-1-4' }),
          field('200', { a: 'X', b: 'Multimédia multisupport' }),
        ),
        record(field('200', { a: 'One piece', b: 'Texte imprimé', e: 'color walk' })),
      ),
    )

    expect(editions).toEqual([])
  })
})

describe('reading a page count', () => {
  test.each([
    ['1 vol. (521 p.)', 521],
    ['208 p.', 208],
    ['1 vol. (non paginé [ca 208] p.)', 208],
    ['1 vol. (non paginé [208 p.])', 208],
    ['XII-345 p.', 345],
    ['Coffret', undefined],
  ])('%s', (description, pages) => {
    expect(pagesIn(description)).toBe(pages)
  })
})

describe('reading an ISBN', () => {
  test('keeps a hyphenated ISBN-13', () => {
    expect(isbn13Of('978-2-07-282204-9')).toBe('9782072822049' as never)
  })

  test('converts an ISBN-10, check digit and all', () => {
    expect(isbn13Of('2-266-07196-X')).toBe('9782266071963' as never)
  })

  test('drops a malformed one', () => {
    expect(isbn13Of('978-2-07-282204-0')).toBeUndefined()
    expect(isbn13Of(undefined)).toBeUndefined()
  })
})

describe('bnfEditionsOf', () => {
  const book = { title: 'La Chambre des curiosités', author: 'Douglas Preston' }
  const catalogueAddress = '194.199.8.30'

  /** Cloudflare's DNS-over-HTTPS answer for the catalogue, a CNAME before the address. */
  const cloudflareAnswers = () =>
    new Response(
      JSON.stringify({
        Status: 0,
        Answer: [
          { name: 'catalogue.bnf.fr', type: 5, data: 'front.bnf.fr.' },
          { name: 'front.bnf.fr', type: 1, data: catalogueAddress },
        ],
      }),
    )

  const catalogueAnswer = () =>
    new Response(answer(record(field('010', { a: '978-2-07-282204-9' }))))

  /** Cloudflare gives the address; the catalogue, reached at it, throws the given error. */
  const catalogueThrows = (error: Error) => {
    spyOn(globalThis, 'fetch').mockImplementation((async () =>
      cloudflareAnswers()) as unknown as typeof fetch)
    return spyOn(dnsOverHttps, 'fetchFromAddress').mockImplementation(async () => {
      throw error
    })
  }

  const reported = () => spyOn(Sentry, 'captureException')

  afterEach(() => {
    ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
    ;(dnsOverHttps.fetchFromAddress as unknown as { mockRestore?: () => void }).mockRestore?.()
    ;(Sentry.captureException as unknown as { mockRestore?: () => void }).mockRestore?.()
  })

  // Google Public DNS, which Cloud Run resolves through, gets no answer from the
  // BnF's two name servers most of the time (SERVFAIL after four seconds, "Name
  // servers did not respond", 2026-11-07), while Cloudflare's resolver does. The
  // address comes from Cloudflare, and the catalogue is reached at it directly.
  test("reads the catalogue at the address Cloudflare gives, never through the platform's resolver", async () => {
    const asked = spyOn(globalThis, 'fetch').mockImplementation((async () =>
      cloudflareAnswers()) as unknown as typeof fetch)
    const reached = spyOn(dnsOverHttps, 'fetchFromAddress').mockImplementation(async () =>
      catalogueAnswer(),
    )
    const reports = reported()

    expect(await bnfEditionsOf(book)).toEqual([{ isbn13: '9782072822049' }] as never)
    expect(asked).toHaveBeenCalledTimes(1)
    expect(String(asked.mock.calls[0]?.[0])).toStartWith('https://1.1.1.1/dns-query?')
    expect(reached).toHaveBeenCalledTimes(1)
    expect(reached.mock.calls[0]?.[0]).toStartWith('https://catalogue.bnf.fr/api/SRU?')
    expect(reached.mock.calls[0]?.[1]).toBe(catalogueAddress)
    // Without a user agent the catalogue answers 403.
    expect(reached.mock.calls[0]?.[2].headers['user-agent']).toStartWith('Shiori/')
    expect(reports).not.toHaveBeenCalled()
  })

  // Cloudflare out of reach is no reason to give the free catalogue up: the
  // platform's resolver may still know the address.
  test("falls back on the platform's resolver when Cloudflare cannot answer", async () => {
    const asked = spyOn(globalThis, 'fetch')
      .mockImplementationOnce((async () => {
        throw new TypeError('fetch failed')
      }) as unknown as typeof fetch)
      .mockImplementationOnce((async () => catalogueAnswer()) as unknown as typeof fetch)
    reported()

    expect(await bnfEditionsOf(book)).toEqual([{ isbn13: '9782072822049' }] as never)
    expect(asked).toHaveBeenCalledTimes(2)
    expect(String(asked.mock.calls[1]?.[0])).toStartWith('https://catalogue.bnf.fr/api/SRU?')
  })

  // The lookup gives the catalogue five seconds, then describes the book another
  // way: a timeout is that cutoff doing its job, nothing to fix.
  test('gives up on a slow catalogue, and reports it to no one', async () => {
    catalogueThrows(new DOMException('The operation was aborted due to timeout', 'TimeoutError'))
    const reports = reported()

    expect(await bnfEditionsOf(book)).toEqual([])
    expect(reports).not.toHaveBeenCalled()
  })

  test('reports the catalogue failing for any other reason', async () => {
    catalogueThrows(new Error('connect ECONNREFUSED 194.199.8.30:443'))
    const reports = reported()

    expect(await bnfEditionsOf(book)).toEqual([])
    expect(reports).toHaveBeenCalledTimes(1)
  })
})
