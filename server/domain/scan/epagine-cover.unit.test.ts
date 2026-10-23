import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import { epagineCoverOf } from '~/domain/scan/epagine-cover'

/** Haut et court, which neither Amazon nor Open Library has a cover for. */
const isbn = Isbn13('9782374343273')

/** Answers every request with the given content type, recording what was asked. */
const epagineAnswers = (answer: string | number | Error) => {
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

describe('epagineCoverOf', () => {
  test('keeps the cover when ePagine answers a JPEG, filed under the EAN’s last three digits', async () => {
    const requests = epagineAnswers('image/jpeg')

    const cover = await epagineCoverOf(isbn)

    expect(String(cover)).toBe('https://images.epagine.fr/273/9782374343273_1_75.jpg')
    expect(requests[0]?.init?.method).toBe('HEAD')
  })

  // A missing cover is a 200 too: a small PNG drawing of a book, which the app
  // would show in place of its own placeholder.
  test('treats the PNG stand-in as no cover', async () => {
    epagineAnswers('image/png')
    expect(await epagineCoverOf(isbn)).toBeUndefined()
  })

  test('gives up quietly when ePagine errors or is unreachable', async () => {
    epagineAnswers(503)
    expect(await epagineCoverOf(isbn)).toBeUndefined()
    ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()

    epagineAnswers(new Error('The operation timed out.'))
    expect(await epagineCoverOf(isbn)).toBeUndefined()
  })
})
