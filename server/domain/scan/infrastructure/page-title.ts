import { createLogger } from '~/system/logger'

const logger = createLogger('scan')

/** How long a page is given to answer. A shared link is one tap away from a
 *  reader waiting on a screen, and a bookshop that hangs must not hold the
 *  whole lookup: past this the title is simply unknown. */
const FETCH_TIMEOUT_MS = 5_000

/** Enough of a page to hold its `<title>`, which sits in the head. Amazon's
 *  pages run to a megabyte of markup and none of the rest is read. */
const MAX_BYTES = 128_000

/** What a bookshop puts around a title and nobody means to search for: the site
 *  itself, the section, the marketing. Cut from both ends, the longest
 *  remaining piece kept. */
const SITE_NOISE =
  /^(amazon(\.[a-z.]+)?|fnac|cultura|decitre|babelio|goodreads|livre|books?|kindle|boutique kindle|ebook|broché|poche|format kindle|achat|vente)$/i

/** The title of a shared page, or undefined when there is none to be had.
 *
 *  Never throws: a link that does not answer, answers something that is not a
 *  page, or answers a page with no title is a lookup that falls back to what
 *  else was shared. A shared link is a convenience, not a contract. */
export const pageTitleOf = async (url: string): Promise<string | undefined> => {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return undefined
  }
  // Only the web. A file:// or data: URL reaching this would be a request to
  // read something the server can see and the reader cannot.
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return undefined

  try {
    const response = await fetch(parsed, {
      redirect: 'follow',
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      headers: {
        // A bookshop serves a different page to something that does not look
        // like a browser, and several serve nothing at all.
        'user-agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
        accept: 'text/html,application/xhtml+xml',
      },
    })
    if (!response.ok) return undefined
    const type = response.headers.get('content-type') ?? ''
    if (!type.includes('html')) return undefined

    const head = (await response.text()).slice(0, MAX_BYTES)
    return cleanedTitleOf(head)
  } catch (error) {
    logger.warn('page title lookup failed', { error, host: parsed.host })
    return undefined
  }
}

/** The `<title>` of a page, stripped of the shop around it. */
export const cleanedTitleOf = (html: string): string | undefined => {
  const match = /<title[^>]*>([\s\S]{0,300}?)<\/title>/i.exec(html)
  if (!match) return undefined

  const decoded = match[1]
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(Number(code)))
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

  // Shops chain their own name, the work, the author and the format with dashes
  // and pipes, in that order — "Amazon.fr - Le Nom du vent - Rothfuss, Patrick -
  // Livres", "Dune | Fnac". The first piece that is none of those is the title.
  // A subtitle after a dash is lost this way, which costs nothing: the lookup
  // that follows finds the book from its title alone.
  const [first] = decoded
    .split(/\s[|–—-]\s|:\s(?=\w)/)
    .map((piece) => piece.trim())
    .filter((piece) => piece !== '' && !SITE_NOISE.test(piece))

  const title = (first ?? decoded).trim()
  return title === '' ? undefined : title
}
