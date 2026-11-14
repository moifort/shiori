import { fetchJson } from '~/utils/fetch'

/** Wikidata, shared by the author pages and the award watch. Both ask under
 *  Shiori's name and throw on an answer that is not a success; each keeps its
 *  own query and its own reading of the answer. */

/** One call to Wikidata's MediaWiki API — `wbsearchentities`,
 *  `wbgetentities`. */
export const askWikidata = <Answer>(
  query: Record<string, string>,
  signal?: AbortSignal,
): Promise<Answer> =>
  fetchJson<Answer>(`https://www.wikidata.org/w/api.php?${new URLSearchParams(query)}`, {
    signal,
  })

/** The bindings a SPARQL query answers on the query service. */
export const queryWikidata = async <Binding>(
  sparql: string,
  signal?: AbortSignal,
): Promise<Binding[]> =>
  (
    await fetchJson<{ results: { bindings: Binding[] } }>(
      `https://query.wikidata.org/sparql?query=${encodeURIComponent(sparql)}`,
      { signal, headers: { accept: 'application/sparql-results+json' } },
    )
  ).results.bindings
