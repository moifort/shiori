import { fetchJson } from '~/utils/fetch'

/** Open Library, shared by the scan, the author pages and the suggestions:
 *  its search, its cover addresses and the probe that tells a cover from none.
 *  Each caller keeps its own timeout, given as `signal`, and its own reading
 *  of the answer. */

/** One search of Open Library: `search.json` for works, `search/authors.json`
 *  for authors. Throws when Open Library cannot be reached or answers an
 *  error. */
export const searchOpenLibrary = <Answer>(
  index: 'search.json' | 'search/authors.json',
  query: Record<string, string>,
  signal: AbortSignal,
): Promise<Answer> =>
  fetchJson<Answer>(`https://openlibrary.org/${index}?${new URLSearchParams(query)}`, { signal })

/** The medium size of a cover Open Library numbered, 180 × ~300 px. With
 *  `default=false` a cover that later disappears fails to load, and the app
 *  falls back to its placeholder rather than a blank frame. */
export const openLibraryCoverOfId = (coverId: number): string =>
  `https://covers.openlibrary.org/b/id/${coverId}-M.jpg?default=false`

/** Whether an Open Library image exists: `found`, `missing`, or the status of
 *  an answer that says neither. The address must carry `default=false`, which
 *  turns a missing image into a 404 rather than a blank 1×1 one.
 *
 *  The redirect is not followed. A found image answers 302 to an archive.org
 *  mirror that takes two seconds to serve; the redirect alone is the answer, in
 *  a fraction of that. Throws when Open Library cannot be reached. */
export const probeOpenLibraryImage = async (
  url: string,
  signal: AbortSignal,
): Promise<'found' | 'missing' | { status: number }> => {
  const response = await fetch(url, { method: 'HEAD', redirect: 'manual', signal })
  if (response.status === 404) return 'missing'
  if (response.ok || (response.status >= 300 && response.status < 400)) return 'found'
  return { status: response.status }
}
