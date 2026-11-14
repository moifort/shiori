/** A text with its accents dropped and its letters kept: "Hélène" reads
 *  "Helene". Only the combining marks go — the accents a decomposed letter
 *  carries; a spacing mark such as "´" or "·" stays a character of its own.
 *  Every comparison that has to ignore accents starts here. */
export const withoutAccents = (value: string): string =>
  value.normalize('NFD').replace(/[\u0300-\u036f]/g, '')

/** A text folded for a loose comparison: no accents, no case, no surrounding
 *  space. "L'Étranger " and "l'etranger" are one title. */
export const foldedText = (value: string): string => withoutAccents(value).toLowerCase().trim()

const LEADING_ARTICLES = /^(the|a|an|le|la|les|l|un|une|des|du|de)[\s-]+/

/** Folds a title, a saga name or an author into a key two spellings of the same
 *  thing agree on. Diacritics are dropped, punctuation collapses to a separator
 *  and a leading article is removed, so "L'Assassin royal" and "Assassin Royal"
 *  meet.
 *
 *  Shared because two different things are keyed on it and they must agree: the
 *  series catalogue's document id, which two readers have to converge on, and the
 *  match that tells an import a book is already on the reader's shelves. */
export const slugify = (value: string): string =>
  withoutAccents(value)
    .toLowerCase()
    .replace(/['’]/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(LEADING_ARTICLES, '')
    .trim()
    .replace(/\s+/g, '-')
