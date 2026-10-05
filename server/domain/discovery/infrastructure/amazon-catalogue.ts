import type { BookLanguage, Isbn13 } from '~/domain/book/types'
import { isbn10Of } from '~/domain/scan/amazon-cover'
import type { ReleaseDate } from '~/domain/series/types'
import { AMAZON_STORES } from '~/domain/shared/amazon-stores'
import { createLogger } from '~/system/logger'
import { amazonEditionFrom } from '../parsing'

const logger = createLogger('amazon-catalogue')

const LOOKUP_TIMEOUT_MS = 8000

export type AmazonEdition = { releaseDate?: ReleaseDate }

/** What Amazon's page for a printed edition says of it: the day it came out or
 *  comes out, or `unknown` when Amazon has no such book in that language, or
 *  `unreachable` when the page could not be read — Amazon answers a robot a
 *  captcha, a 500 or a 503 now and then, and that is not an answer. A 979 ISBN has no ASIN a
 *  page can be read at, and is `unreachable` too. */
export const amazonEditionOf = async (
  isbn13: Isbn13,
  language: BookLanguage,
): Promise<AmazonEdition | 'unknown' | 'unreachable'> => {
  const asin = isbn10Of(isbn13)
  const store = AMAZON_STORES[language]
  if (!asin || !store) return 'unreachable'
  try {
    const response = await fetch(`https://www.${store}/dp/${asin}`, {
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
      headers: {
        // Amazon serves nothing at all to a client that does not look like a
        // browser.
        'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
        accept: 'text/html,application/xhtml+xml',
      },
    })
    if (response.status === 404) return 'unknown'
    // A 500 or a 503 is Amazon turning a robot away, as its captcha does: pages
    // it answered a 500 in a burst read fine the next morning. Read again next week.
    if (response.status >= 500) {
      logger.info('Amazon turned the lookup away', { isbn13, store, status: response.status })
      return 'unreachable'
    }
    if (!response.ok) {
      logger.warn('Amazon edition lookup failed', { isbn13, status: response.status })
      return 'unreachable'
    }
    const html = await response.text()
    const edition = amazonEditionFrom(html, language)
    // Amazon's robot check comes and goes, and the page is read again next week.
    if (edition === 'captcha') {
      logger.info('Amazon answered a captcha', { isbn13, store })
      return 'unreachable'
    }
    // The page's title and size say what came back, since the page itself is not kept.
    if (edition === 'unreadable') {
      const title = html.match(/<title>([^<]*)<\/title>/)?.[1]?.trim()
      logger.warn('Amazon edition page unreadable', { isbn13, store, title, length: html.length })
      return 'unreachable'
    }
    return edition
  } catch (error) {
    logger.warn('Amazon edition lookup failed', { error, isbn13 })
    return 'unreachable'
  }
}
