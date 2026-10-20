import { describe, expect, test } from 'bun:test'
import { editionsIn, isbn13Of, pagesIn } from '~/domain/scan/bnf'

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
