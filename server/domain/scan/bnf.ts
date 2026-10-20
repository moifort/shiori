import { Isbn13, PageCount } from '~/domain/book/primitives'
import type { LibraryEdition } from '~/domain/scan/types'
import { createLogger } from '~/system/logger'
import { isPresent, optionally } from '~/utils/input'

const logger = createLogger('bnf')

/** The catalogue answers in under a second; past this, the grounded lookup
 *  the caller falls back on is the better wait. */
const LOOKUP_TIMEOUT_MS = 5000

/** Enough for every printing of a novel, and for a numbered volume once its
 *  number is in the query. */
const MAX_RECORDS = 50

/** What names a printed book to search the BnF with. */
export type CataloguedBook = {
  title: string
  author: string
  /** The volume number, said only when the volume is titled after its saga:
   *  "One Piece 5" finds volume 5, where "One Piece" alone answers 370 records. */
  volume?: number
}

/** The printed editions the Bibliothèque nationale de France lists for a book,
 *  in the order its catalogue ranks them; empty when it finds none.
 *
 *  The BnF is the French legal deposit: every book printed in France is
 *  recorded there, with its ISBN, its page count, its collection and volume,
 *  and for most recent ones the publisher's blurb. It costs nothing and needs
 *  no key, which is why a French edition is described from it before any paid
 *  web search. Its SRU interface answers UNIMARC records.
 *
 *  Never throws: a catalogue that cannot be reached is a lookup the caller
 *  makes another way. */
export const bnfEditionsOf = async (book: CataloguedBook): Promise<LibraryEdition[]> => {
  const words = `${book.title}${book.volume !== undefined ? ` ${book.volume}` : ''}`
  const query = `bib.title all "${cqlWords(words)}" and bib.author all "${cqlWords(surnameOf(book.author))}"`
  const url = `https://catalogue.bnf.fr/api/SRU?${new URLSearchParams({
    version: '1.2',
    operation: 'searchRetrieve',
    recordSchema: 'unimarcxchange',
    maximumRecords: String(MAX_RECORDS),
    query,
  })}`
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS) })
    if (!response.ok) {
      logger.warn('BnF lookup failed', { status: response.status, title: book.title })
      return []
    }
    return editionsIn(await response.text())
  } catch (error) {
    logger.warn('BnF lookup failed', { error, title: book.title })
    return []
  }
}

/** The last word of a name, which the catalogue indexes whatever order the
 *  record writes it in: "Oda, Eiichirō" and "Eiichirō Oda" both hold "Oda". */
const surnameOf = (author: string) => author.trim().split(/\s+/).at(-1) ?? author

/** Words a CQL phrase can hold: its own quotes would close it. */
const cqlWords = (text: string) =>
  text
    .replace(/["«»\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

/** What is not a printed book: a recording, a film, a digital file. */
const NOT_PRINTED = /multimédia|enregistrement|ressource|image animée|musique/i

/** The printed editions in an SRU answer, each with an ISBN. Exported for its
 *  tests: the parsing is where a catalogue's habits show. */
export const editionsIn = (xml: string): LibraryEdition[] =>
  [...xml.matchAll(/<mxc:record[\s\S]*?<\/mxc:record>/g)]
    .map(([record]) => fieldsOf(record))
    .filter((fields) => !NOT_PRINTED.test(fields.get('200')?.[0]?.b ?? ''))
    .map(editionOf)
    .filter(isPresent)

type Subfields = Record<string, string>

const editionOf = (fields: Map<string, Subfields[]>): LibraryEdition | undefined => {
  const isbn13 = isbn13Of(fields.get('010')?.[0]?.a)
  if (!isbn13) return undefined
  const title = fields.get('200')?.[0]
  // 214 is the publication statement since 2016; older records carry 210.
  const imprint = fields.get('214')?.[0] ?? fields.get('210')?.[0]
  const collection = fields.get('225')?.[0]
  const set = fields.get('461')?.[0]
  const edition: LibraryEdition = {
    isbn13,
    title: [title?.a, title?.h, title?.i, title?.e].filter(Boolean).join(' — ') || undefined,
    publisher: imprint?.c,
    year: /\d{4}/.exec(imprint?.d ?? '')?.[0],
    pageCount: optionally(pagesIn(fields.get('215')?.[0]?.a), PageCount),
    collection: collection?.a ?? set?.t,
    // Not the collection's number: a Folio's is its rank in Folio, not a volume.
    volume: title?.h ?? set?.v,
    summary: fields.get('330')?.[0]?.a,
  }
  return Object.fromEntries(
    Object.entries(edition).filter(([, value]) => value !== undefined),
  ) as LibraryEdition
}

/** The page count in a physical description: "1 vol. (521 p.)", "208 p.",
 *  "1 vol. (non paginé [ca 208] p.)" — the last number before "p.". */
export const pagesIn = (description: string | undefined): number | undefined => {
  const pages = /(\d+)\]?\s*p\./.exec(description ?? '')?.[1]
  return pages ? Number(pages) : undefined
}

/** The ISBN-13 of an ISBN as a record writes it: hyphenated, and ten digits
 *  long on anything printed before 2007. */
export const isbn13Of = (raw: string | undefined) => {
  const digits = (raw ?? '').replace(/[^0-9X]/gi, '')
  if (digits.length === 13) return optionally(digits, Isbn13)
  if (digits.length !== 10) return undefined
  const core = `978${digits.slice(0, 9)}`
  const sum = [...core].reduce(
    (total, digit, index) => total + Number(digit) * (index % 2 ? 3 : 1),
    0,
  )
  return optionally(`${core}${(10 - (sum % 10)) % 10}`, Isbn13)
}

/** A record's fields, tag to each occurrence's subfields, the first of each code. */
const fieldsOf = (record: string) => {
  const fields = new Map<string, Subfields[]>()
  for (const [, tag, body] of record.matchAll(
    /<mxc:datafield[^>]*tag="(\d+)"[^>]*>([\s\S]*?)<\/mxc:datafield>/g,
  )) {
    const subfields: Subfields = {}
    for (const [, code, value] of body.matchAll(
      /<mxc:subfield code="(.)">([\s\S]*?)<\/mxc:subfield>/g,
    ))
      subfields[code] ??= decoded(value).trim()
    fields.set(tag, [...(fields.get(tag) ?? []), subfields])
  }
  return fields
}

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }

const decoded = (text: string) =>
  text.replace(/&(amp|lt|gt|quot|apos);/g, (_, name: string) => ENTITIES[name])
