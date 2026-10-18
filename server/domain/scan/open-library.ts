import { CoverUrl } from '~/domain/book/primitives'
import type { CoverUrl as CoverUrlType, Isbn13 } from '~/domain/book/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('open-library')

/** The medium size, 180 × ~300 px and around 20 KB. The small one is 58 px tall
 *  and blurs on a Retina list row; the app scales this one down instead. */
const coverUrlOf = (isbn13: Isbn13) => `https://covers.openlibrary.org/b/isbn/${isbn13}-M.jpg`

/** A slow answer costs the reader a longer scan for a cosmetic field. Past this,
 *  the book is added without a cover rather than kept waiting. */
const LOOKUP_TIMEOUT_MS = 3000

/** Open Library's cover for an ISBN, or undefined when it has none.
 *
 *  Checked once, at scan time, so a library of 300 books never probes 300 URLs.
 *  `default=false` is what makes the check possible: without it a missing cover
 *  answers 200 with a blank 1×1 image, which the app would draw as an empty frame
 *  instead of the placeholder. With it, a missing cover is a 404.
 *
 *  The redirect is not followed. A found cover answers 302 to an archive.org
 *  mirror that takes two seconds to serve; the redirect alone is the answer, in
 *  a fraction of that. The URL kept is the stable one, not the mirror's, and it
 *  carries `default=false` too: a cover that later disappears then fails to load,
 *  and the app falls back to its placeholder rather than a blank frame.
 *
 *  Never throws: a failed lookup is a book without a cover, not a failed scan. */
export const openLibraryCoverOf = async (isbn13: Isbn13): Promise<CoverUrlType | undefined> => {
  const url = coverUrlOf(isbn13)
  try {
    const response = await fetch(`${url}?default=false`, {
      method: 'HEAD',
      redirect: 'manual',
      signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
    })
    if (response.status === 404) return undefined
    if (response.ok || (response.status >= 300 && response.status < 400))
      return CoverUrl(`${url}?default=false`)
    logger.warn('Open Library cover lookup failed', { isbn13, status: response.status })
    return undefined
  } catch (error) {
    logger.warn('Open Library cover lookup failed', { error, isbn13 })
    return undefined
  }
}

type SearchAnswer = { docs?: { cover_i?: number }[] }

/** Open Library's cover for a work named by its title and author, or undefined
 *  when the search finds none. For a book known by title alone — an author's
 *  bibliography, which the model cannot give ISBNs for.
 *
 *  Asked with the ORIGINAL title: Open Library files a work under it, and finds
 *  "The End of Eternity" where "La Fin de l'Éternité" finds nothing. The cover
 *  is therefore the edition Open Library shows for the work, often the original
 *  one rather than the reader's translation.
 *
 *  Throws when Open Library cannot be reached or answers an error: a whole
 *  bibliography is looked up at once, and the caller stops asking at the first
 *  failure rather than logging and waiting on each of forty. */
export const openLibraryCoverByTitle = async (
  title: string,
  author: string,
): Promise<CoverUrlType | undefined> => {
  const query = new URLSearchParams({ title, author, fields: 'cover_i', limit: '1' })
  const response = await fetch(`https://openlibrary.org/search.json?${query}`, {
    // Open Library asks every client to say who it is, and throttles those that don't.
    headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
    signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
  })
  if (!response.ok) throw new Error(`Open Library title search answered ${response.status}`)
  const coverId = ((await response.json()) as SearchAnswer).docs?.[0]?.cover_i
  return coverId
    ? CoverUrl(`https://covers.openlibrary.org/b/id/${coverId}-M.jpg?default=false`)
    : undefined
}

/** What names a book on a spine, to search Open Library with. */
export type PrintedBook = {
  title: string
  author: string
  /** The volume number printed beside a saga's name: without it, a search for
   *  "Naruto" answers volume 33. */
  volume?: number
  /** ISO 639-1, the edition's language: Open Library ranks that edition first. */
  language: string
}

type IsbnAnswer = { docs?: { isbn?: string[] }[] }

/** The ISBNs Open Library files under the work a spine names, every edition and
 *  language mixed, in the order Open Library gives them; empty when it finds
 *  nothing. For a book added from a shelf photo, whose cover is looked up
 *  without the model that would otherwise name its ISBN.
 *
 *  Asked twice at most: by title and author fields first, which finds a volume
 *  by its number ("ONE PIECE 5"), then, when that finds nothing, by a query on
 *  both, which finds a translated title the fields miss ("L'Apprenti assassin").
 *
 *  Never throws: a failed search is a book without a cover, not a failed add. */
export const openLibraryIsbnsOf = async (book: PrintedBook): Promise<string[]> => {
  const title = book.volume ? `${book.title} ${book.volume}` : book.title
  const narrow = { title, author: book.author }
  const broad = { q: `title:(${title}) author:(${book.author})` }
  try {
    const first = await isbnsFound(narrow, book.language)
    return first.length > 0 ? first : await isbnsFound(broad, book.language)
  } catch (error) {
    logger.warn('Open Library ISBN search failed', { error, title: book.title })
    return []
  }
}

const isbnsFound = async (search: Record<string, string>, language: string) => {
  const query = new URLSearchParams({ ...search, lang: language, fields: 'isbn', limit: '1' })
  const response = await fetch(`https://openlibrary.org/search.json?${query}`, {
    headers: { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' },
    signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
  })
  if (!response.ok) throw new Error(`Open Library search answered ${response.status}`)
  return ((await response.json()) as IsbnAnswer).docs?.[0]?.isbn ?? []
}
