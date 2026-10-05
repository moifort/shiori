import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
import type { Isbn13 } from '~/domain/book/types'
import { amazonEditionOf } from './amazon-catalogue'

const isbn13 = '9781538752043' as Isbn13

const answering = (status: number) =>
  spyOn(globalThis, 'fetch').mockResolvedValue(new Response('', { status }))

const reported = () => spyOn(Sentry, 'captureMessage')

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
  ;(Sentry.captureMessage as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('an Amazon edition page', () => {
  // Amazon turns a robot away with a 500 as readily as with a 503: the page is
  // read again next week, and nobody has anything to fix.
  test.each([500, 503])('answered %i is unreachable, and reported to no one', async (status) => {
    answering(status)
    const reports = reported()

    expect(await amazonEditionOf(isbn13, 'en')).toBe('unreachable')
    expect(reports).not.toHaveBeenCalled()
  })

  test('answered a status Amazon never turns a robot away with is reported', async () => {
    answering(403)
    const reports = reported()

    expect(await amazonEditionOf(isbn13, 'en')).toBe('unreachable')
    expect(reports).toHaveBeenCalledTimes(1)
  })
})
