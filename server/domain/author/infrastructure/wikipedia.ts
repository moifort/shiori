import { PortraitUrl } from '~/domain/author/primitives'
import type { PortraitUrl as PortraitUrlType } from '~/domain/author/types'
import type { AuthorName } from '~/domain/shared/types'
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

type Wiki = 'en' | 'fr'

/** The page to read and the Wikipedia it is on. */
type Candidate = { wiki: Wiki; title: string }

/** The photograph Wikipedia shows at the top of the author's page, or
 *  undefined when no page of theirs has one.
 *
 *  The model's title is tried first, but it is a model's: it comes back null,
 *  or names a page that does not exist, and the author kept their initials
 *  for good. So the author's own name is tried too, on the English
 *  Wikipedia and then on the French one, where a French writer of comics or
 *  young adult fiction may be the only one to have a page. A name usually
 *  lands on the author's page or on a disambiguation page, which is refused.
 *  The lookups run at once, so a miss costs no more than one timeout, and the
 *  first page in that order with a photograph wins.
 *
 *  Never throws: a missing portrait is the initials, not a failed page. */
export const portraitOf = async (
  name: AuthorName,
  pageTitle?: string,
): Promise<PortraitUrlType | undefined> => {
  const found = await Promise.all(candidatesOf(name, pageTitle).map(summaryPortrait))
  return found.find((portrait) => portrait !== undefined)
}

/** Every page worth asking, once each, in the order they are trusted. */
const candidatesOf = (name: AuthorName, pageTitle?: string): Candidate[] => {
  const all: Candidate[] = [
    ...(pageTitle?.trim() ? [{ wiki: 'en' as const, title: pageTitle.trim() }] : []),
    { wiki: 'en', title: name },
    { wiki: 'fr', title: name },
  ]
  const asked = new Set<string>()
  return all.filter(({ wiki, title }) => {
    const id = `${wiki}:${pageTitleOf(title)}`
    if (asked.has(id)) return false
    asked.add(id)
    return true
  })
}

const pageTitleOf = (title: string) => title.replaceAll(' ', '_')

/** One page's photograph, read from the REST summary rather than asked of the
 *  model: a model writes image URLs that look right and 404. The thumbnail
 *  first: 330 px wide, it fills an 84-point circle on a Retina screen, where
 *  the original is the photographer's full file, megabytes of it. The original
 *  stands in for a page with no thumbnail. A redirect — "Ursula Le Guin" — is
 *  followed to the page it names. */
const summaryPortrait = async ({
  wiki,
  title,
}: Candidate): Promise<PortraitUrlType | undefined> => {
  const url = `https://${wiki}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(pageTitleOf(title))}`
  try {
    const response = await fetch(url, {
      // Wikimedia asks every client to say who it is, and throttles those that don't.
      headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (response.status === 404) return undefined
    if (!response.ok) {
      logger.warn('Wikipedia summary lookup failed', { wiki, title, status: response.status })
      return undefined
    }
    const summary = (await response.json()) as Summary
    if (summary.type === 'disambiguation') return undefined
    const source = summary.thumbnail?.source ?? summary.originalimage?.source
    return source ? PortraitUrl(source) : undefined
  } catch (error) {
    logger.warn('Wikipedia summary lookup failed', { error, wiki, title })
    return undefined
  }
}
