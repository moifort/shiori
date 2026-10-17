import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
import { CoverUrl } from '~/domain/book/primitives'
import { coverOf } from '~/domain/suggestion/infrastructure/catalogue'

/** Answers the Open Library search with `docs` (an Error fails it). */
const openLibraryAnswers = (docs: { cover_i?: number }[] | Error) =>
  spyOn(globalThis, 'fetch').mockImplementation((async () => {
    if (docs instanceof Error) throw docs
    return Response.json({ docs })
  }) as unknown as typeof fetch)

const reported = () => spyOn(Sentry, 'captureException')

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
  ;(Sentry.captureException as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('coverOf', () => {
  test('lends the first cover Open Library has', async () => {
    openLibraryAnswers([{}, { cover_i: 8231856 }])

    expect(await coverOf('The Caves of Steel', 'Isaac Asimov')).toBe(
      CoverUrl('https://covers.openlibrary.org/b/id/8231856-M.jpg?default=false'),
    )
  })

  // The lookup gives Open Library five seconds and shows the suggestion without
  // a cover past that: a timeout is that cutoff doing its job, nothing to fix.
  test('gives up on a slow Open Library, and reports it to no one', async () => {
    openLibraryAnswers(new DOMException('The operation was aborted due to timeout', 'TimeoutError'))
    const reports = reported()

    expect(await coverOf('The Caves of Steel', 'Isaac Asimov')).toBeUndefined()
    expect(reports).not.toHaveBeenCalled()
  })

  test('reports Open Library failing for any other reason', async () => {
    openLibraryAnswers(new Error('getaddrinfo ENOTFOUND openlibrary.org'))
    const reports = reported()

    expect(await coverOf('The Caves of Steel', 'Isaac Asimov')).toBeUndefined()
    expect(reports).toHaveBeenCalledTimes(1)
  })
})
