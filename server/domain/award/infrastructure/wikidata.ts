import type { Award } from '~/domain/award/types'

/** The English label of each award's item on Wikidata: looked up by label
 *  rather than by Q-id so a wrong id cannot silently match nothing. */
const LABELS: Record<Award, string> = {
  hugo: 'Hugo Award for Best Novel',
  nebula: 'Nebula Award for Best Novel',
  'locus-sf': 'Locus Award for Best Science Fiction Novel',
  'locus-fantasy': 'Locus Award for Best Fantasy Novel',
  clarke: 'Arthur C. Clarke Award',
  'world-fantasy': 'World Fantasy Award for Best Novel',
}

const ENDPOINT = 'https://query.wikidata.org/sparql'

const AUTHORS_SEPARATOR = '|'

/** Every work that received the award after a year, with its English title
 *  and authors. Only works with an author: the people who won are recorded as
 *  receiving the award too, and a work entered without its author yet is
 *  taken on a later day, once it has one. */
const queryOf = (award: Award, after: number) => `
SELECT ?title ?year (GROUP_CONCAT(DISTINCT ?authorName; separator="${AUTHORS_SEPARATOR}") AS ?authors) WHERE {
  ?award rdfs:label "${LABELS[award]}"@en .
  ?work p:P166 ?statement .
  ?statement ps:P166 ?award ; pq:P585 ?date .
  BIND(YEAR(?date) AS ?year)
  FILTER(?year > ${after})
  ?work wdt:P50 ?author .
  ?author rdfs:label ?authorName . FILTER(LANG(?authorName) = "en")
  ?work rdfs:label ?title . FILTER(LANG(?title) = "en")
} GROUP BY ?work ?title ?year`

type Binding = { title: { value: string }; year: { value: string }; authors: { value: string } }

export type WikidataWinner = { year: number; title: string; authors: string[] }

/** The winners a SPARQL answer lists, the authors in the order Wikidata gave. */
export const winnersOfAnswer = (bindings: readonly Binding[]): WikidataWinner[] =>
  bindings.flatMap(({ title, year, authors }) => {
    const names = authors.value
      .split(AUTHORS_SEPARATOR)
      .map((name) => name.trim())
      .filter(Boolean)
    const presented = Number(year.value)
    return names.length > 0 && Number.isInteger(presented)
      ? [{ year: presented, title: title.value.trim(), authors: names }]
      : []
  })

/** The award's winners Wikidata records after a year. Throws on an answer that
 *  is not a success: the caller logs it and asks again the next day. */
export const winnersAfter = async (award: Award, after: number): Promise<WikidataWinner[]> => {
  const response = await fetch(`${ENDPOINT}?query=${encodeURIComponent(queryOf(award, after))}`, {
    headers: {
      Accept: 'application/sparql-results+json',
      'User-Agent': 'shiori-award-watch/1.0 (https://github.com/moifort/shiori)',
    },
  })
  if (!response.ok) throw new Error(`Wikidata answered ${response.status}`)
  const body = (await response.json()) as { results: { bindings: Binding[] } }
  return winnersOfAnswer(body.results.bindings)
}
