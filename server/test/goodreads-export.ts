import { readFileSync } from 'node:fs'

/** A Goodreads library export as the site writes it in 2026, byte for byte the
 *  layout of a real `goodreads_library_export.csv`: every column of the current
 *  format, ISBNs as quoted spreadsheet formulas (`"=""9780765326355"""`, an
 *  empty one `"="""""`), dates with slashes, the to-read and currently-reading
 *  shelves repeated in Bookshelves (read is not), several shelves quoted
 *  together, a review in HTML, a custom "dnf" shelf, LF line endings and a
 *  final newline. Test data only. */
export const GOODREADS_EXPORT = readFileSync(
  new URL('./goodreads_library_export.csv', import.meta.url),
  'utf8',
)
