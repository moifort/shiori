/**
 * Compares the award winners Découvrir lists with Wikidata, after a ceremony or
 * when one is doubted.
 *
 *   bun scripts/check-award-winners.ts
 *
 * For each award, one SPARQL query asks Wikidata for every work that received
 * it, with the year. A year whose winners differ from server/domain/award/winners.ts
 * is printed with both sides. Wikidata is not the authority either: a
 * difference is checked against the award's own list before the file changes.
 * Exits 1 when something differs, 0 otherwise.
 */

import type { Award } from '../server/domain/award/types'
import { WINNERS } from '../server/domain/award/winners'

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

const queryOf = (label: string) => `
SELECT ?title ?year WHERE {
  ?award rdfs:label "${label}"@en .
  ?work p:P166 ?statement .
  ?statement ps:P166 ?award ; pq:P585 ?date .
  BIND(YEAR(?date) AS ?year)
  ?work rdfs:label ?title . FILTER(LANG(?title) = "en")
}`

const normalized = (title: string) =>
  title
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()

const winnersOnWikidata = async (award: Award): Promise<Map<number, Set<string>>> => {
  const response = await fetch(`${ENDPOINT}?query=${encodeURIComponent(queryOf(LABELS[award]))}`, {
    headers: {
      Accept: 'application/sparql-results+json',
      'User-Agent': 'shiori-award-check/1.0 (https://github.com/moifort/shiori)',
    },
  })
  if (!response.ok) throw new Error(`Wikidata answered ${response.status} for ${award}`)
  const body = (await response.json()) as {
    results: { bindings: { title: { value: string }; year: { value: string } }[] }
  }
  const byYear = new Map<number, Set<string>>()
  for (const { title, year } of body.results.bindings) {
    const key = Number(year.value)
    byYear.set(key, (byYear.get(key) ?? new Set()).add(title.value))
  }
  return byYear
}

let differences = 0
for (const award of Object.keys(LABELS) as Award[]) {
  const theirs = await winnersOnWikidata(award)
  const ours = new Map<number, string[]>()
  for (const [year, title] of WINNERS[award]) ours.set(year, [...(ours.get(year) ?? []), title])
  const years = [...new Set([...ours.keys(), ...theirs.keys()])].sort((a, b) => a - b)
  const found = theirs.size
  for (const year of years) {
    const mine = (ours.get(year) ?? []).map(normalized).sort()
    const wiki = [...(theirs.get(year) ?? [])].map(normalized).sort()
    if (mine.join('|') === wiki.join('|')) continue
    // A year Wikidata lacks is printed too: it often trails the latest
    // ceremony, which is what a reader checks by hand.
    differences += 1
    console.log(
      `${award} ${year}: ours [${(ours.get(year) ?? []).join(', ')}] — Wikidata [${[
        ...(theirs.get(year) ?? []),
      ].join(', ')}]`,
    )
  }
  console.log(`${award}: ${WINNERS[award].length} listed here, ${found} years on Wikidata`)
}
process.exit(differences === 0 ? 0 : 1)
