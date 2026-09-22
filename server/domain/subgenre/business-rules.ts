import type { LocalizedSubgenre, Subgenre } from '~/domain/book/types'
import { type Language, SUPPORTED_LANGUAGES } from '~/domain/shared/language'
import { slugify } from '~/utils/slug'

/** The dictionary key of a label in one language. Folded as the series keys
 *  are, so "Dark fantasy" and "dark-fantasy" find the same entry; a label that
 *  folds to nothing — "+", say — is keyed on itself rather than on an empty
 *  string every such label would share. */
export const translationKeyOf = (label: Subgenre, language: Language): string =>
  `${language}-${slugify(label) || encodeURIComponent(label.toLocaleLowerCase())}`

/** Every key an entry is filed under: one per language, so a label is found
 *  from whichever side the reader typed it on. */
export const translationKeysOf = (subgenre: LocalizedSubgenre): string[] =>
  SUPPORTED_LANGUAGES.map((language) => translationKeyOf(subgenre[language], language))

/** A label that could not be translated reads the same in every language:
 *  better the reader's own word than no subgenre at all. */
export const untranslated = (label: Subgenre): LocalizedSubgenre =>
  Object.fromEntries(SUPPORTED_LANGUAGES.map((language) => [language, label])) as Record<
    Language,
    Subgenre
  >

/** The labels in one language, folded on case so a list never offers the same
 *  word twice. Order kept: the head of a book's list is the one a row shows. */
export const labelsIn = (
  subgenres: readonly LocalizedSubgenre[],
  language: Language,
): Subgenre[] => {
  const seen = new Set<string>()
  return subgenres.flatMap((subgenre) => {
    const label = subgenre[language]
    const key = label.toLocaleLowerCase()
    if (seen.has(key)) return []
    seen.add(key)
    return [label]
  })
}
