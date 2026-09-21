import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import { publishedCoverOf } from '~/domain/scan/published-cover'

const isbn = Isbn13('9782070612758')

/** Answers Open Library and Amazon each their own way, recording which was asked. */
const sourcesAnswer = ({ openLibrary, amazon }: { openLibrary: number; amazon: string }) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    if (url.includes('openlibrary.org')) {
      asked.push('open-library')
      return new Response(null, { status: openLibrary })
    }
    asked.push('amazon')
    return new Response(null, { status: 200, headers: { 'content-type': amazon } })
  }) as unknown as typeof fetch)
  return asked
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('publishedCoverOf', () => {
  test('keeps Open Library and never asks Amazon when it has the cover', async () => {
    const asked = sourcesAnswer({ openLibrary: 302, amazon: 'image/jpeg' })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('covers.openlibrary.org')
    expect(asked).toEqual(['open-library'])
  })

  test('falls back to Amazon when Open Library has none', async () => {
    const asked = sourcesAnswer({ openLibrary: 404, amazon: 'image/jpeg' })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('m.media-amazon.com')
    expect(asked).toEqual(['open-library', 'amazon'])
  })

  test('has no cover when neither source has one', async () => {
    sourcesAnswer({ openLibrary: 404, amazon: 'image/gif' })
    expect(await publishedCoverOf(isbn)).toBeUndefined()
  })
})
