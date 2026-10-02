import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { CoverUrl, Isbn13 } from '~/domain/book/primitives'
import { isCoverGone, publishedCoverOf } from '~/domain/scan/published-cover'

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

/** Answers every probe with one response, or fails it when given an Error. */
const coverAnswers = (answer: Response | Error) =>
  spyOn(globalThis, 'fetch').mockImplementation((async () => {
    if (answer instanceof Error) throw answer
    return answer
  }) as unknown as typeof fetch)

const stored = CoverUrl('https://m.media-amazon.com/images/P/2070612759.01._SCLZZZZZZZ_.jpg')

describe('isCoverGone', () => {
  test('is gone when the source answers 404', async () => {
    coverAnswers(new Response(null, { status: 404 }))
    expect(await isCoverGone(stored)).toBe(true)
  })

  test('is gone when the source answers its blank stand-in', async () => {
    coverAnswers(
      new Response(null, {
        status: 200,
        headers: { 'content-type': 'image/gif', 'content-length': '43' },
      }),
    )
    expect(await isCoverGone(stored)).toBe(true)
  })

  test('still loads when the source answers an image', async () => {
    coverAnswers(
      new Response(null, {
        status: 200,
        headers: { 'content-type': 'image/jpeg', 'content-length': '21504' },
      }),
    )
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('still loads when Open Library redirects to its mirror', async () => {
    coverAnswers(new Response(null, { status: 302 }))
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('is kept when the source cannot be reached', async () => {
    coverAnswers(new Error('The operation was aborted due to timeout'))
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('is kept when the source answers an error of its own', async () => {
    coverAnswers(new Response(null, { status: 503 }))
    expect(await isCoverGone(stored)).toBe(false)
  })
})
