import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import { publishedCoverOf } from '~/domain/scan/open-library'

const isbn = Isbn13('9780756404741')

/** Answers every request with the given status, recording what was asked. */
const openLibraryAnswers = (answer: number | Error) => {
  const requests: { url: string; init?: RequestInit }[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string, init?: RequestInit) => {
    requests.push({ url, init })
    if (answer instanceof Error) throw answer
    return new Response(null, { status: answer })
  }) as unknown as typeof fetch)
  return requests
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('publishedCoverOf', () => {
  // A found cover redirects to an archive.org mirror. The redirect is the answer;
  // following it would cost two more seconds on every scan.
  test('keeps the medium cover when Open Library redirects to it', async () => {
    const requests = openLibraryAnswers(302)

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toBe(
      'https://covers.openlibrary.org/b/isbn/9780756404741-M.jpg?default=false',
    )
    expect(requests[0]?.init?.method).toBe('HEAD')
    expect(requests[0]?.init?.redirect).toBe('manual')
  })

  // Without `default=false` a missing cover answers 200 with a blank image, and
  // the app would draw an empty frame instead of its placeholder.
  test('asks for a 404 rather than a blank image when there is no cover', async () => {
    const requests = openLibraryAnswers(404)

    const cover = await publishedCoverOf(isbn)

    expect(cover).toBeUndefined()
    expect(requests[0]?.url).toContain('default=false')
  })

  test('gives up quietly when Open Library errors or is unreachable', async () => {
    openLibraryAnswers(503)
    expect(await publishedCoverOf(isbn)).toBeUndefined()
    ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()

    openLibraryAnswers(new Error('The operation timed out.'))
    expect(await publishedCoverOf(isbn)).toBeUndefined()
  })
})
