/**
 * Compares, book by book, the three ways `lookUpEdition` can describe a named
 * book: from the BnF's catalogue alone, from Google Books alone — each with an
 * ungrounded model call — and from the grounded web search both fall back on.
 * Runs the real code against the real APIs, with the Firestore fake standing
 * in for storage. A catalogue that cannot describe a book is shown as such,
 * rather than falling back: the point is what each one covers.
 *
 * A manual check, never part of `bun test`: the web column bills four to six
 * Google searches a book (≈ €0.08), twenty-one books ≈ €1.70. `--no-web`
 * leaves it out, for about two cents. Writes `.context-enrichment-bench.html`.
 *
 * Usage: NITRO_GOOGLE_API_KEY=... NITRO_GOOGLE_BOOKS_KEY=... \
 *          bun scripts/bench-enrichment.ts [--no-web]
 */

import { mock } from 'bun:test'
import { writeFileSync } from 'node:fs'
import { fakeDb, resetFakeFirestore } from '../server/test/fake-firestore'

const apiKey = process.env.NITRO_GOOGLE_API_KEY
const booksKey = process.env.NITRO_GOOGLE_BOOKS_KEY
if (!apiKey || !booksKey) {
  process.stderr.write('NITRO_GOOGLE_API_KEY and NITRO_GOOGLE_BOOKS_KEY must be set\n')
  process.exit(1)
}
const withWeb = !process.argv.includes('--no-web')

// `$fetch` is a Nitro auto-import, provided as the deployed function has it.
const { ofetch } = await import('ofetch')
;(globalThis as unknown as { $fetch: typeof ofetch }).$fetch = ofetch
mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: apiKey, googleBooksKey: booksKey }),
}))
resetFakeFirestore()

type Column = 'bnf' | 'google' | 'web'
let column: Column = 'bnf'
const lookedUp: string[] = []
const counted = (editions: { summary?: string }[]) => {
  lookedUp.push(`${editions.length} éditions, ${editions.filter((e) => e.summary).length} résumés`)
  return editions
}

// Each column switches the other sources off; a catalogue column refuses the
// web search, so a book it cannot describe shows as such instead of costing.
const bnf = await import('~/domain/scan/bnf')
const bnfOf = bnf.bnfEditionsOf
mock.module('~/domain/scan/bnf', () => ({
  ...bnf,
  bnfEditionsOf: async (book: Parameters<typeof bnfOf>[0]) =>
    column === 'bnf' ? counted(await bnfOf(book)) : [],
}))
const google = await import('~/domain/scan/google-books')
const googleOf = google.googleBooksEditionsOf
mock.module('~/domain/scan/google-books', () => ({
  ...google,
  googleBooksEditionsOf: async (book: Parameters<typeof googleOf>[0]) =>
    column === 'google' ? counted(await googleOf(book)) : [],
}))
const gemini = await import('~/domain/scan/gemini')
const generateOf = gemini.generate
mock.module('~/domain/scan/gemini', () => ({
  ...gemini,
  generate: (options: Parameters<typeof generateOf>[0]) => {
    if (options.step === 'enrichment' && column !== 'web')
      throw new Error('not described by this catalogue')
    return generateOf(options)
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
  {
    title: 'James',
    author: 'Percival Everett',
    publisher: 'Doubleday',
    language: 'en',
    reader: 'en',
  },
  {
    title: 'Tomorrow, and Tomorrow, and Tomorrow',
    author: 'Gabrielle Zevin',
    publisher: 'Knopf',
    language: 'en',
    reader: 'fr',
  },
  {
    title: 'Onyx Storm',
    author: 'Rebecca Yarros',
    publisher: 'Entangled',
    language: 'en',
    series: { name: 'The Empyrean', volume: 3 },
    reader: 'en',
  },
  {
    title: 'The Housemaid',
    author: 'Freida McFadden',
    publisher: 'Bookouture',
    language: 'en',
    series: { name: 'The Housemaid', volume: 1 },
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

const described = async (book: Case, side: Column): Promise<Side> => {
  column = side
  lookedUp.length = 0
  const started = Date.now()
  try {
    const { result, usage } = await ScanCommand.lookUpEdition(seenOf(book), book.reader)
    return {
      result,
      searches: usage.enrichment?.searches ?? 0,
      ms: Date.now() - started,
      via: lookedUp[0],
    }
  } catch (error) {
    return {
      searches: 0,
      ms: Date.now() - started,
      via: lookedUp[0] ?? 'rien trouvé',
      failed: (error as Error).message,
    }
  }
}

const rows: { book: Case; sides: Partial<Record<Column, Side>> }[] = []
for (const book of CASES) {
  const sides: Partial<Record<Column, Side>> = {
    bnf: await described(book, 'bnf'),
    google: await described(book, 'google'),
    ...(withWeb && { web: await described(book, 'web') }),
  }
  rows.push({ book, sides })
  const line = (side: Side | undefined) =>
    side
      ? side.result
        ? `${side.result.isbn13 ?? '—'}${side.result.coverUrl ? '' : ' (pas de couv.)'}`
        : 'non décrit'
      : '—'
  process.stdout.write(
    `${book.title} (${book.language}→${book.reader}) | BnF ${line(sides.bnf)} | Google ${line(sides.google)} | web ${line(sides.web)}\n`,
  )
}

const escaped = (text: unknown) =>
  String(text ?? '—').replace(
    /[&<>"]/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] as string,
  )

const LABELS: Record<Column, string> = {
  bnf: 'BnF + Flash-Lite',
  google: 'Google Books + Flash-Lite',
  web: 'Recherche web (Gemini groundé)',
}

const cell = (side: Column, found: Side | undefined) => {
  if (!found) return `<div class="side"><h3>${LABELS[side]}</h3><p>(non lancé)</p></div>`
  const r = found.result
  if (!r)
    return `<div class="side off"><h3>${LABELS[side]}</h3><p>Non décrit${found.via ? ` — ${escaped(found.via)}` : ''}</p></div>`
  return `<div class="side"><h3>${LABELS[side]}</h3>
<img src="${escaped(r.coverUrl ?? '')}" alt="pas de couverture">
<dl>
<dt>ISBN</dt><dd>${escaped(r.isbn13)}</dd>
<dt>Éditeur</dt><dd>${escaped(r.publisher)}</dd>
<dt>Pages</dt><dd>${escaped(r.pageCount)}</dd>
<dt>1re publ.</dt><dd>${escaped(r.firstPublishedIn)}</dd>
<dt>Genre</dt><dd>${escaped(r.genre)} — ${escaped(r.subgenres?.join(', '))}</dd>
<dt>Coût</dt><dd>${found.searches} recherche(s) · ${(found.ms / 1000).toFixed(1)} s${found.via ? ` · ${escaped(found.via)}` : ''}</dd>
</dl>
<p>${escaped(r.synopsis)}</p></div>`
}

const covered = (side: Column) => rows.filter(({ sides }) => sides[side]?.result).length
const coveredIn = (side: Column, language: string) =>
  `${rows.filter(({ book, sides }) => book.language === language && sides[side]?.result).length}/${rows.filter(({ book }) => book.language === language).length}`

const html = `<!doctype html><meta charset="utf-8"><title>Banc enrichment</title>
<style>
body{font:14px -apple-system,system-ui;margin:24px;color:#222}
.row{border-top:1px solid #ddd;padding:16px 0}
.row h2{font-size:16px;margin:0 0 8px}
.trio{display:grid;grid-template-columns:1fr 1fr 1fr;gap:20px}
.side img{height:150px;float:left;margin:0 10px 8px 0;background:#eee;min-width:96px}
dl{display:grid;grid-template-columns:70px 1fr;margin:0;font-size:12px}dt{color:#888}dd{margin:0}
.side p{clear:both;font-size:13px;line-height:1.4}.off{opacity:.5}
h3{font-size:12px;text-transform:uppercase;color:#888;margin:0 0 6px}
table{border-collapse:collapse;margin:8px 0 16px}td,th{border:1px solid #ddd;padding:4px 10px}
</style>
<h1>Enrichment : BnF, Google Books, recherche web</h1>
<table><tr><th></th><th>Livres en français</th><th>Livres en anglais</th><th>Total</th></tr>
${(['bnf', 'google', 'web'] as Column[])
  .map(
    (side) =>
      `<tr><th>${LABELS[side]}</th><td>${coveredIn(side, 'fr')}</td><td>${coveredIn(side, 'en')}</td><td>${covered(side)}/${rows.length}</td></tr>`,
  )
  .join('')}</table>
${rows
  .map(
    ({
      book,
      sides,
    }) => `<div class="row"><h2>${escaped(book.title)} — ${escaped(book.author)}${book.series ? ` · ${escaped(book.series.name)} ${book.series.volume ?? ''}` : ''} · ${escaped(book.publisher)} · édition ${book.language}, lecteur ${book.reader}</h2>
<div class="trio">${cell('bnf', sides.bnf)}${cell('google', sides.google)}${cell('web', sides.web)}</div></div>`,
  )
  .join('\n')}`

writeFileSync('.context-enrichment-bench.html', html)
process.stdout.write('\nWrote .context-enrichment-bench.html\n')
