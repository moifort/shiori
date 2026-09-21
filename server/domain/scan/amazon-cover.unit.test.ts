import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import { amazonCoverOf, isbn10Of } from '~/domain/scan/amazon-cover'

const isbn = Isbn13('9782070612758')

/** Answers every request with the given content type, recording what was asked. */
const amazonAnswers = (answer: string | number | Error) => {
  const requests: { url: string; init?: RequestInit }[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string, init?: RequestInit) => {
    requests.push({ url, init })
    if (answer instanceof Error) throw answer
    if (typeof answer === 'number') return new Response(null, { status: answer })
    return new Response(null, { status: 200, headers: { 'content-type': answer } })
  }) as unknown as typeof fetch)
  return requests
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('isbn10Of', () => {
  test('drops the 978 prefix and recomputes the check digit', () => {
    expect(isbn10Of(isbn)).toBe('2070612759')
  })

  test('writes a check digit of ten as X', () => {
    expect(isbn10Of(Isbn13('9781000000016'))).toBe('100000001X')
  })

  test('has nothing for a 979 ISBN, which never had an ISBN-10', () => {
    expect(isbn10Of(Isbn13('9791032705278'))).toBeUndefined()
  })
})

describe('amazonCoverOf', () => {
  test('keeps the cover when Amazon answers a JPEG', async () => {
    const requests = amazonAnswers('image/jpeg')

    const cover = await amazonCoverOf(isbn)

    expect(String(cover)).toBe('https://m.media-amazon.com/images/P/2070612759.01._SCLZZZZZZZ_.jpg')
    expect(requests[0]?.init?.method).toBe('HEAD')
  })

  // A missing cover is not a 404 but a 43-byte transparent GIF, which the app
  // would draw as an empty frame instead of its placeholder.
  test('treats the transparent GIF as no cover', async () => {
    amazonAnswers('image/gif')
    expect(await amazonCoverOf(isbn)).toBeUndefined()
  })

  test('asks nothing for a 979 ISBN', async () => {
    const requests = amazonAnswers('image/jpeg')
    expect(await amazonCoverOf(Isbn13('9791032705278'))).toBeUndefined()
    expect(requests).toHaveLength(0)
  })

  test('gives up quietly when Amazon errors or is unreachable', async () => {
    amazonAnswers(503)
    expect(await amazonCoverOf(isbn)).toBeUndefined()
    ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()

    amazonAnswers(new Error('The operation timed out.'))
    expect(await amazonCoverOf(isbn)).toBeUndefined()
  })
})
