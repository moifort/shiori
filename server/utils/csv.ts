/** Reading the CSV files readers export from other services: an Amazon data
 *  export, a Goodreads library export. */

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
