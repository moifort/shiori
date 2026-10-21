import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
import { Isbn13 } from '~/domain/book/primitives'
import {
  openLibraryCoverByTitle,
  openLibraryCoverOf,
  openLibraryIsbnsOf,
} from '~/domain/scan/open-library'

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

const reported = () => spyOn(Sentry, 'captureException')

const timedOut = () => new DOMException('The operation was aborted due to timeout', 'TimeoutError')

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
  ;(Sentry.captureException as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('openLibraryCoverOf', () => {
  // A found cover redirects to an archive.org mirror. The redirect is the answer;
  // following it would cost two more seconds on every scan.
  test('keeps the medium cover when Open Library redirects to it', async () => {
    const requests = openLibraryAnswers(302)

    const cover = await openLibraryCoverOf(isbn)

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

    const cover = await openLibraryCoverOf(isbn)

    expect(cover).toBeUndefined()
    expect(requests[0]?.url).toContain('default=false')
  })

  test('gives up quietly when Open Library errors or is unreachable', async () => {
    openLibraryAnswers(503)
    expect(await openLibraryCoverOf(isbn)).toBeUndefined()
    ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()

    openLibraryAnswers(new Error('The operation timed out.'))
    expect(await openLibraryCoverOf(isbn)).toBeUndefined()
  })

  // The lookup gives Open Library three seconds and adds the book without a
  // cover past that: a timeout is that cutoff doing its job, nothing to fix.
  test('gives up on a slow Open Library, and reports it to no one', async () => {
    openLibraryAnswers(timedOut())
    const reports = reported()

    expect(await openLibraryCoverOf(isbn)).toBeUndefined()
    expect(reports).not.toHaveBeenCalled()
  })

  test('reports Open Library failing for any other reason', async () => {
    openLibraryAnswers(new Error('getaddrinfo ENOTFOUND covers.openlibrary.org'))
    const reports = reported()

    expect(await openLibraryCoverOf(isbn)).toBeUndefined()
    expect(reports).toHaveBeenCalledTimes(1)
  })
})

describe('openLibraryIsbnsOf', () => {
  const book = { title: 'Exit Strategy', author: 'Martha Wells', language: 'en' }

  // A shelf photo's book is added without a cover once the three seconds run out.
  test('gives up on a slow Open Library, and reports it to no one', async () => {
    openLibraryAnswers(timedOut())
    const reports = reported()

    expect(await openLibraryIsbnsOf(book)).toEqual([])
    expect(reports).not.toHaveBeenCalled()
  })

  test('reports Open Library failing for any other reason', async () => {
    openLibraryAnswers(503)
    const reports = reported()

    expect(await openLibraryIsbnsOf(book)).toEqual([])
    expect(reports).toHaveBeenCalledTimes(1)
  })
})

describe('openLibraryCoverByTitle', () => {
  // A bibliography's forty searches stop at the first failure: the caller has
  // to be told, rather than handed the same answer as a work without a cover.
  test('throws when Open Library errors or is unreachable', async () => {
    openLibraryAnswers(503)
    await expect(openLibraryCoverByTitle('Dune', 'Frank Herbert')).rejects.toThrow('503')
    ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()

    openLibraryAnswers(new Error('The operation was aborted due to timeout'))
    await expect(openLibraryCoverByTitle('Dune', 'Frank Herbert')).rejects.toThrow('timeout')
  })
})
