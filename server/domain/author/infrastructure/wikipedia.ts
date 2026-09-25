import { PortraitUrl } from '~/domain/author/primitives'
import type { PortraitUrl as PortraitUrlType } from '~/domain/author/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('wikipedia')

/** A slow answer costs the reader a longer first opening for a cosmetic field.
 *  Past this, the page is built with the initials rather than kept waiting. */
const LOOKUP_TIMEOUT_MS = 4000

type Summary = {
  type?: string
  originalimage?: { source?: string }
  thumbnail?: { source?: string }
}

/** The photograph Wikipedia shows at the top of an English page, or undefined
 *  when the page has none or does not exist.
 *
 *  Read from the REST summary rather than asked of the model: a model writes
 *  image URLs that look right and 404. The page title is the model's, which is
 *  why a disambiguation page — a list of namesakes, not the author — is refused.
 *  The thumbnail first: 330 px wide, it fills an 84-point circle on a Retina
 *  screen, where the original is the photographer's full file, megabytes of it.
 *  The original stands in for a page with no thumbnail.
 *
 *  Never throws: a missing portrait is the initials, not a failed page. */
export const portraitOf = async (pageTitle: string): Promise<PortraitUrlType | undefined> => {
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(pageTitle.replaceAll(' ', '_'))}`
  try {
    const response = await fetch(url, {
      // Wikimedia asks every client to say who it is, and throttles those that don't.
      headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (response.status === 404) return undefined
    if (!response.ok) {
      logger.warn('Wikipedia summary lookup failed', { pageTitle, status: response.status })
      return undefined
    }
    const summary = (await response.json()) as Summary
    if (summary.type === 'disambiguation') return undefined
    const source = summary.thumbnail?.source ?? summary.originalimage?.source
    return source ? PortraitUrl(source) : undefined
  } catch (error) {
    logger.warn('Wikipedia summary lookup failed', { error, pageTitle })
    return undefined
  }
}
