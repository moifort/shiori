/**
 * Compares, book by book, the two ways a named book is described: from the
 * BnF's catalogue with an ungrounded model call, as `lookUpEdition` does first
 * for a French edition, and from the grounded web search it falls back on.
 * Runs the real code against the real Gemini API and the real catalogue, with
 * the Firestore fake standing in for storage.
 *
 * A manual check, never part of `bun test`: the grounded side bills four to
 * six Google searches a book (≈ €0.08), seventeen books ≈ €1.40. `--cheap`
 * runs the catalogue side alone, for about a cent. Writes
 * `.context-enrichment-bench.html`, covers side by side.
 *
 * Usage: NITRO_GOOGLE_API_KEY=... bun scripts/bench-enrichment.ts [--cheap]
 */

import { mock } from 'bun:test'
import { writeFileSync } from 'node:fs'
import { fakeDb, resetFakeFirestore } from '../server/test/fake-firestore'

const apiKey = process.env.NITRO_GOOGLE_API_KEY
if (!apiKey) {
  process.stderr.write('NITRO_GOOGLE_API_KEY is unset\n')
  process.exit(1)
}
const cheap = process.argv.includes('--cheap')

// `$fetch` is a Nitro auto-import, provided as the deployed function has it.
const { ofetch } = await import('ofetch')
;(globalThis as unknown as { $fetch: typeof ofetch }).$fetch = ofetch
mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({ config: () => ({ googleApiKey: apiKey }) }))
resetFakeFirestore()

// The grounded side is the same lookup with a catalogue that lists nothing.
const bnf = await import('~/domain/scan/bnf')
const catalogueOf = bnf.bnfEditionsOf
let catalogueOn = true
const lookedUp: string[] = []
mock.module('~/domain/scan/bnf', () => ({
  ...bnf,
  bnfEditionsOf: async (book: Parameters<typeof catalogueOf>[0]) => {
    if (!catalogueOn) return []
    const editions = await catalogueOf(book)
    lookedUp.push(`${editions.length} editions, ${editions.filter((e) => e.summary).length} blurbs`)
    return editions
  },
}))

const { ScanCommand } = await import('~/domain/scan/command')
const { seriesKeyOf } = await import('~/domain/series/primitives')
type ScanResult = import('~/domain/scan/types').ScanResult

type Case = {
  title: string
  author: string
  format?: 'book' | 'manga' | 'bande-dessinee' | 'comic'
  publisher?: string
  language: string
  series?: { name: string; volume?: number }
  reader: 'fr' | 'en'
}

const CASES: Case[] = [
  {
    title: 'La Horde du Contrevent',
    author: 'Alain Damasio',
    publisher: 'Gallimard',
    language: 'fr',
    reader: 'fr',
  },
  {
    title: "L'Apprenti assassin",
    author: 'Robin Hobb',
    publisher: 'Pygmalion',
    language: 'fr',
    series: { name: "L'Assassin royal", volume: 1 },
    reader: 'fr',
  },
  {
    title: 'One Piece',
    author: 'Eiichirō Oda',
    format: 'manga',
    publisher: 'Glénat',
    language: 'fr',
    series: { name: 'One Piece', volume: 5 },
    reader: 'fr',
  },
  {
    title: 'Quelque part entre les ombres',
    author: 'Juan Díaz Canales',
    format: 'bande-dessinee',
    publisher: 'Dargaud',
    language: 'fr',
    series: { name: 'Blacksad', volume: 1 },
    reader: 'fr',
  },
  {
    title: 'Le Nom du vent',
    author: 'Patrick Rothfuss',
    publisher: 'Bragelonne',
    language: 'fr',
    series: { name: 'Chronique du tueur de roi', volume: 1 },
    reader: 'fr',
  },
  {
    title: 'Les Furtifs',
    author: 'Alain Damasio',
    publisher: 'La Volte',
    language: 'fr',
    reader: 'fr',
  },
  {
    title: 'La Maison vide',
    author: 'Laurent Mauvignier',
    publisher: 'Les Éditions de Minuit',
    language: 'fr',
    reader: 'fr',
  },
  {
    title: 'Frieren',
    author: 'Kanehito Yamada',
    format: 'manga',
    publisher: 'Ki-oon',
    language: 'fr',
    series: { name: 'Frieren', volume: 10 },
    reader: 'fr',
  },
  {
    title: "L'Empire ultime",
    author: 'Brandon Sanderson',
    publisher: 'Le Livre de Poche',
    language: 'fr',
    series: { name: 'Fils-des-Brumes', volume: 1 },
    reader: 'fr',
  },
  {
    title: 'Astérix en Lusitanie',
    author: 'Fabcaro',
    format: 'bande-dessinee',
    publisher: 'Éditions Albert René',
    language: 'fr',
    series: { name: 'Astérix', volume: 41 },
    reader: 'fr',
  },
  {
    title: 'Kafka sur le rivage',
    author: 'Haruki Murakami',
    publisher: '10/18',
    language: 'fr',
    reader: 'fr',
  },
  {
    title: 'Le Problème à trois corps',
    author: 'Liu Cixin',
    publisher: 'Actes Sud',
    language: 'fr',
    series: { name: 'Le Problème à trois corps', volume: 1 },
    reader: 'fr',
  },
  {
    title: "Les Aiguilles d'or",
    author: 'Michael McDowell',
    publisher: 'Monsieur Toussaint Louverture',
    language: 'fr',
    reader: 'fr',
  },
  {
    title: 'Project Hail Mary',
    author: 'Andy Weir',
    publisher: 'Ballantine Books',
    language: 'en',
    reader: 'fr',
  },
  {
    title: 'Fourth Wing',
    author: 'Rebecca Yarros',
    publisher: 'Entangled',
    language: 'en',
    series: { name: 'The Empyrean', volume: 1 },
    reader: 'en',
  },
  {
    title: 'Wind and Truth',
    author: 'Brandon Sanderson',
    publisher: 'Tor',
    language: 'en',
    series: { name: 'The Stormlight Archive', volume: 5 },
    reader: 'en',
  },
  // A French novel described for an English-speaking reader: the translation.
  {
    title: 'La Horde du Contrevent',
    author: 'Alain Damasio',
    publisher: 'Gallimard',
    language: 'fr',
    reader: 'en',
  },
]

const seenOf = (book: Case) => {
  const format = book.format ?? 'book'
  return {
    recognized: true,
    title: book.title,
    authors: [book.author],
    format,
    publisher: book.publisher,
    language: book.language,
    subgenres: [],
    ...(book.series && {
      series: {
        id: seriesKeyOf(book.series.name, book.author, format),
        name: book.series.name,
        volume: book.series.volume,
        kind: 'main',
      },
    }),
  } as unknown as ScanResult
}

type Side = { result?: ScanResult; searches: number; ms: number; failed?: string; via?: string }

const described = async (book: Case, withCatalogue: boolean): Promise<Side> => {
  catalogueOn = withCatalogue
  lookedUp.length = 0
  const started = Date.now()
  try {
    const { result, usage } = await ScanCommand.lookUpEdition(seenOf(book), book.reader)
    return {
      result,
      searches: usage.enrichment?.searches ?? 0,
      ms: Date.now() - started,
      via: withCatalogue ? (lookedUp[0] ?? 'not asked') : undefined,
    }
  } catch (error) {
    return { searches: 0, ms: Date.now() - started, failed: String(error) }
  }
}

const rows: { book: Case; catalogue: Side; web?: Side }[] = []
for (const book of CASES) {
  const catalogue = await described(book, true)
  const web = cheap ? undefined : await described(book, false)
  rows.push({ book, catalogue, web })
  const line = (side: Side | undefined) =>
    side
      ? `${side.result?.isbn13 ?? '—'} ${side.result?.coverUrl ? 'cover' : 'no cover'} s=${side.searches}`
      : '—'
  process.stdout.write(
    `${book.title} (${book.reader}) | catalogue ${line(catalogue)} [${catalogue.via}] | web ${line(web)}\n`,
  )
}

const escaped = (text: unknown) =>
  String(text ?? '—').replace(
    /[&<>"]/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] as string,
  )

const column = (label: string, side: Side | undefined) => {
  if (!side) return `<div class="side"><h3>${label}</h3><p>(non lancé)</p></div>`
  const r = side.result
  const fellBack = side.via !== undefined && side.searches > 0
  return `<div class="side"><h3>${label}${fellBack ? ' — repli sur le web' : ''}</h3>
<img src="${escaped(r?.coverUrl ?? '')}" alt="pas de couverture">
<dl>
<dt>ISBN</dt><dd>${escaped(r?.isbn13)}</dd>
<dt>Éditeur</dt><dd>${escaped(r?.publisher)}</dd>
<dt>Pages</dt><dd>${escaped(r?.pageCount)}</dd>
<dt>1re publication</dt><dd>${escaped(r?.firstPublishedIn)}</dd>
<dt>Genre</dt><dd>${escaped(r?.genre)} — ${escaped(r?.subgenres?.join(', '))}</dd>
<dt>Coût</dt><dd>${side.searches} recherche(s) · ${(side.ms / 1000).toFixed(1)} s${side.via ? ` · BnF : ${escaped(side.via)}` : ''}</dd>
</dl>
<p>${escaped(r?.synopsis)}</p>${side.failed ? `<p class="err">${escaped(side.failed)}</p>` : ''}</div>`
}

const html = `<!doctype html><meta charset="utf-8"><title>Banc enrichment</title>
<style>
body{font:14px -apple-system,system-ui;margin:24px;color:#222}
.row{border-top:1px solid #ddd;padding:16px 0}
.row h2{font-size:16px;margin:0 0 8px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:24px}
.side img{height:180px;float:left;margin:0 12px 8px 0;background:#eee;min-width:110px}
dl{display:grid;grid-template-columns:110px 1fr;margin:0;font-size:12px}dt{color:#888}dd{margin:0}
.side p{clear:both;font-size:13px;line-height:1.4}.err{color:#b00}
h3{font-size:12px;text-transform:uppercase;color:#888;margin:0 0 6px}
</style>
<h1>Enrichment : catalogue BnF + Flash-Lite vs recherche web</h1>
${rows
  .map(
    ({
      book,
      catalogue,
      web,
    }) => `<div class="row"><h2>${escaped(book.title)} — ${escaped(book.author)}${book.series ? ` · ${escaped(book.series.name)} ${book.series.volume ?? ''}` : ''} · ${escaped(book.publisher)} · lecteur ${book.reader}</h2>
<div class="pair">${column('Catalogue d’abord (nouveau)', catalogue)}${column('Recherche web (avant)', web)}</div></div>`,
  )
  .join('\n')}`

writeFileSync('.context-enrichment-bench.html', html)
process.stdout.write('\nWrote .context-enrichment-bench.html\n')
