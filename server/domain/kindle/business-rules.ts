import { shelfKeyOf } from '~/domain/book/business-rules'
import type { NewBook } from '~/domain/book/command'
import type { Book } from '~/domain/book/types'
import type { ImportableKindleBook, UnreadableExport } from '~/domain/kindle/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import { optionally } from '~/utils/input'

/** The separators a spreadsheet writes. Amazon serves commas; a French Excel
 *  that opened and saved the file writes semicolons, and the reader is not going
 *  to know which one they are handing us. */
const DELIMITERS = [',', ';', '\t'] as const

/** Whichever separator the header line holds most of. Quotes are ignored here:
 *  a column heading carrying a separator inside quotes is not a thing any of the
 *  three export formats does, and reading the line properly first would need the
 *  answer this is working out. */
export const delimiterOf = (text: string): string => {
  const [firstLine = ''] = text.split(/\r?\n/, 1)
  let best: string = DELIMITERS[0]
  let bestCount = -1
  for (const candidate of DELIMITERS) {
    const count = firstLine.split(candidate).length - 1
    if (count > bestCount) {
      bestCount = count
      best = candidate
    }
  }
  return best
}

/** Split a CSV into rows, tolerating everything a spreadsheet does to a file: a
 *  quoted field holding the separator or a line break, a doubled quote standing
 *  for one inside it, Windows line endings, and a byte order mark at the head.
 *
 *  Blank rows are dropped rather than carried as empty records: an export
 *  usually ends with one, and a trailing empty row would become a book with no
 *  title further down. */
export const csvRowsOf = (text: string, delimiter: string): string[][] => {
  const input = text.replace(/^﻿/, '')
  const rows: string[][] = []
  let row: string[] = []
  let field = ''
  let quoted = false

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index]
    if (quoted) {
      if (char !== '"') {
        field += char
      } else if (input[index + 1] === '"') {
        field += '"'
        index += 1
      } else {
        quoted = false
      }
      continue
    }
    if (char === '"') quoted = true
    else if (char === delimiter) {
      row.push(field)
      field = ''
    } else if (char === '\n') {
      row.push(field)
      rows.push(row)
      row = []
      field = ''
    } else if (char !== '\r') field += char
  }
  if (field !== '' || row.length > 0) {
    row.push(field)
    rows.push(row)
  }
  return rows.filter((entry) => entry.some((value) => value.trim() !== ''))
}

/** A heading reduced to its letters and digits, so "Product Name", "product_name"
 *  and "ProductName" are one thing. Amazon renames its columns between exports
 *  and does not agree with itself on spacing or case. */
const normalized = (value: string): string => value.toLowerCase().replace(/[^a-z0-9]/g, '')

const TITLE_COLUMNS = [
  'title',
  'producttitle',
  'productname',
  'booktitle',
  'itemtitle',
  'digitalordersitemname',
  'titre',
]

const AUTHOR_COLUMNS = [
  'author',
  'authors',
  'authorname',
  'authornames',
  'byline',
  'contributor',
  'creator',
  'auteur',
  'auteurs',
]

/** The column a field lives in: an exact heading first, then one that merely
 *  starts with a known name. Exact first on purpose — "AuthorName" starts with
 *  nothing in the title list but "Name" would have caught it the other way. */
const columnOf = (headers: readonly string[], candidates: readonly string[]): number => {
  const folded = headers.map(normalized)
  const exact = folded.findIndex((heading) => candidates.includes(heading))
  if (exact >= 0) return exact
  return folded.findIndex((heading) =>
    candidates.some((candidate) => heading.startsWith(candidate)),
  )
}

/** Suffixes that are not a first name, so "Smith, Jr." is not read as "Jr. Smith". */
const SUFFIXES = /^(jr|sr|ph\.?d|m\.?d|[ivx]+)\.?$/i

/** The people named in one cell. Amazon separates several with a semicolon or a
 *  pipe, and files each one surname first — "Rothfuss, Patrick" — which is how a
 *  catalogue sorts but not how anybody says it. A single comma with a real name
 *  on both sides is turned back around; anything else is left exactly as it came,
 *  because a guess that reorders a name is worse than a name read oddly. */
export const authorsOf = (cell: string | undefined): string[] =>
  (cell ?? '')
    .split(/[;|]/)
    .map((name) => name.trim())
    .filter((name) => name !== '')
    .map((name) => {
      const parts = name.split(',').map((part) => part.trim())
      if (parts.length !== 2) return name
      const [last, first] = parts
      if (last === '' || first === '' || SUFFIXES.test(first)) return name
      return `${first} ${last}`
    })

// The duplicate check the Audible import uses, so a novel already on the shelf
// from a scan is recognized here whatever edition each of them is.
export { shelfKeyOf }

/** Read an Amazon data export into rows the reader can tick.
 *
 *  Answers `'no-title-column'` for a file with no column that could hold a
 *  title: the reader picked the wrong CSV out of the archive, and an empty list
 *  would tell them there is nothing to import, which is a different thing.
 *
 *  A title appearing twice in the file — a book bought again, a sample and the
 *  book — is one row: the export is a purchase history, and a reader does not
 *  want their library to count their purchases. */
export const importablesFrom = (
  csv: string,
  owned: readonly Book[],
): ImportableKindleBook[] | UnreadableExport => {
  const rows = csvRowsOf(csv, delimiterOf(csv))
  const [headers, ...body] = rows
  if (!headers) return 'no-title-column'

  const titleColumn = columnOf(headers, TITLE_COLUMNS)
  if (titleColumn < 0) return 'no-title-column'
  const authorColumn = columnOf(headers, AUTHOR_COLUMNS)

  const ownedKeys = new Set(owned.map((book) => shelfKeyOf(book.title, book.authors[0])))
  const seen = new Set<string>()
  const importables: ImportableKindleBook[] = []

  for (const row of body) {
    const title = optionally(row[titleColumn]?.trim(), BookTitle)
    if (!title) continue
    const authors = (authorColumn >= 0 ? authorsOf(row[authorColumn]) : [])
      .map((name) => optionally(name, AuthorName))
      .filter((name): name is ReturnType<typeof AuthorName> => name !== undefined)

    const key = shelfKeyOf(title, authors[0])
    if (seen.has(key)) continue
    seen.add(key)

    importables.push({ key, title, authors, alreadyInLibrary: ownedKeys.has(key) })
  }
  return importables
}

/** The record an import writes. `format` is `ebook`: that is what the reader
 *  owns, whatever edition the work also exists in.
 *
 *  Everything else is left absent rather than guessed. The export carries a
 *  purchase date, which is not when the work was published and not when the
 *  reader started it, and nothing else at all — so the book lands on the pile
 *  with its title and its author, and the reader fills the rest in, or scans
 *  the cover, if they ever care to. */
export const bookFrom = (importable: ImportableKindleBook): NewBook => ({
  title: importable.title,
  authors: importable.authors,
  format: 'ebook',
  status: 'to-read',
})
