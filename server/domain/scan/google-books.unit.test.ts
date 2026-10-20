import { describe, expect, test } from 'bun:test'
import { editionOf } from '~/domain/scan/google-books'

describe('reading a Google Books volume', () => {
  test('reads an edition: ISBN, publisher, year, pages, volume, blurb as text', () => {
    expect(
      editionOf({
        volumeInfo: {
          title: 'Fourth Wing',
          subtitle: 'Discover the Instant Sunday Times Number One Bestseller',
          publisher: 'Entangled: Red Tower Books',
          publishedDate: '2023-05-02',
          pageCount: 528,
          industryIdentifiers: [
            { type: 'ISBN_10', identifier: '1649374046' },
            { type: 'ISBN_13', identifier: '9781649374042' },
          ],
          seriesInfo: { bookDisplayNumber: '1' },
          description: '<p>Twenty-year-old Violet Sorrengail&#39;s <b>fate</b>.</p><p>Fly.</p>',
        },
      }),
    ).toEqual({
      isbn13: '9781649374042',
      title: 'Fourth Wing — Discover the Instant Sunday Times Number One Bestseller',
      publisher: 'Entangled: Red Tower Books',
      year: '2023',
      pageCount: 528,
      volume: '1',
      summary: "Twenty-year-old Violet Sorrengail's fate. Fly.",
    } as never)
  })

  test('falls back on the ISBN-10', () => {
    expect(
      editionOf({
        volumeInfo: {
          title: 'X',
          industryIdentifiers: [{ type: 'ISBN_10', identifier: '226607196X' }],
        },
      })?.isbn13,
    ).toBe('9782266071963' as never)
  })

  test('leaves out a volume with no ISBN', () => {
    expect(
      editionOf({
        volumeInfo: { title: 'X', industryIdentifiers: [{ type: 'OTHER', identifier: 'UOM:1' }] },
      }),
    ).toBeUndefined()
  })
})
