import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import { publishedCoverOf } from '~/domain/scan/published-cover'

const isbn = Isbn13('9782070612758')
/** A 979 ISBN has no ISBN-10, so Amazon cannot be asked for it at all. */
const isbn979 = Isbn13('9791030703184')

/** Answers Amazon and Open Library each their own way, recording which was asked. */
const sourcesAnswer = ({ amazon, openLibrary }: { amazon: string; openLibrary: number }) => {
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
  test('keeps Amazon and never asks Open Library when it has the cover', async () => {
    const asked = sourcesAnswer({ amazon: 'image/jpeg', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('m.media-amazon.com')
    expect(asked).toEqual(['amazon'])
  })

  test('falls back to Open Library when Amazon answers its placeholder', async () => {
    const asked = sourcesAnswer({ amazon: 'image/gif', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('covers.openlibrary.org')
    expect(asked).toEqual(['amazon', 'open-library'])
  })

  test('goes straight to Open Library for a 979 ISBN, which Amazon cannot file', async () => {
    const asked = sourcesAnswer({ amazon: 'image/jpeg', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn979)

    expect(String(cover)).toContain('covers.openlibrary.org')
    expect(asked).toEqual(['open-library'])
  })

  test('has no cover when neither source has one', async () => {
    sourcesAnswer({ amazon: 'image/gif', openLibrary: 404 })
    expect(await publishedCoverOf(isbn)).toBeUndefined()
  })
})
