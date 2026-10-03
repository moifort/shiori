import type { BookTitle } from '~/domain/shared/types'

/** A volume's title without the saga it belongs to.
 *
 *  A book carries its saga's name and its volume number in fields of their own,
 *  and the screens show them beside the title. Publishers, stores and the model
 *  often write them into the title as well — "Crescent City, Tome 1 : Maison de
 *  la Terre et du Sang", "Old Boy, tome 2" — and the reader then reads them
 *  twice. Shared rather than owned by one domain: a book and a saga's catalogue
 *  both title their volumes by it. */

const VOLUME = String.raw`(?:\b(?:tome|livre|book|volume|vol\.?|band|libro|t\.?)\s*(?:\d+(?:\.\d+)?|[ivxlc]+\b)|#\d+)`
const SEPARATOR = '[-–—:,.]'

const LEADING_VOLUME = new RegExp(String.raw`^${VOLUME}\s*(?:${SEPARATOR}\s*|$)`, 'iu')
const TRAILING_VOLUME = new RegExp(String.raw`\s*(?:${SEPARATOR}\s*)?\(?${VOLUME}\)?$`, 'iu')
/** "Fearless (Powerless, Book 3)", "Le Nom du vent (Chronique du tueur de roi, tome 1)" */
const TRAILING_SAGA = new RegExp(String.raw`\s*\([^()]*${VOLUME}\)$`, 'iu')
/** The bare number some covers put after the saga: "Crescent City 1 : …", "Old Boy 2". */
const LEADING_NUMBER = new RegExp(String.raw`^\d{1,3}\s*(?:${SEPARATOR}\s*|$)`, 'u')
const LEADING_SEPARATORS = new RegExp(String.raw`^(?:\s|${SEPARATOR})+`, 'u')

/** The rest of the title when it opens on the saga's name, or undefined when it
 *  does not: "Dune Messiah" opens on "Dune" no more than "Dunes" does. */
const afterSaga = (title: string, saga: string): string | undefined => {
  if (!title.toLowerCase().startsWith(saga.toLowerCase())) return undefined
  const rest = title.slice(saga.length)
  if (rest !== '' && !/^[\s\-–—:,.(]/u.test(rest)) return undefined
  return rest.replace(LEADING_SEPARATORS, '')
}

/** The title with the saga and the volume number taken out, when the title
 *  names them; unchanged otherwise. A title that is nothing but the saga and its
 *  number — "Old Boy, tome 2" — is the saga's name: a volume with no title of
 *  its own goes by its saga's. The saga's name is dropped only with a volume
 *  named after it: "La Légende des Firemane - L'intégrale" is the title of that
 *  book, not a volume of it. */
export const titleWithoutSaga = (title: string, saga: string | undefined): string => {
  const trimmed = title.trim()
  const name = saga?.trim()
  if (!name) return trimmed
  const base = trimmed.replace(TRAILING_SAGA, '').trim() || trimmed

  const rest = afterSaga(base, name)
  if (rest !== undefined) {
    if (rest === '') return base
    const opening = rest.match(LEADING_VOLUME) ?? rest.match(LEADING_NUMBER)
    if (opening) return rest.slice(opening[0].length).trim() || name
    const closing = rest.match(TRAILING_VOLUME)
    if (closing) return rest.slice(0, closing.index).trim() || name
    return base
  }

  const opening = base.match(LEADING_VOLUME)
  if (opening) return base.slice(opening[0].length).trim() || name
  return base.replace(TRAILING_VOLUME, '').trim() || name
}

/** `titleWithoutSaga` on a title already checked: what it returns is a part of
 *  that title, or the saga's name, and never empty. */
export const bareTitleOf = <Title extends BookTitle | ''>(
  title: Title,
  saga: string | undefined,
): Title => titleWithoutSaga(title, saga) as Title
