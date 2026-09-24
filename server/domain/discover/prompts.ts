import { BOOK_LANGUAGES } from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'
import type { ForeignWork } from './types'

/** Written into the prompt so the editions come back in the reader's language. */
const LANGUAGE_NAMES: Record<Language, string> = { fr: 'français', en: 'anglais' }

const workLine = (key: string, work: ForeignWork) => {
  const author = work.author ? ` de ${work.author}` : ''
  return work.kind === 'series'
    ? `- ${key} : la série « ${work.title} »${author}, lue en '${work.language}' — tous ses tomes.`
    : `- ${key} : le livre « ${work.title} »${author}, lu en '${work.language}'.`
}

/** Every edition, out or announced, of these works in the reader's language,
 *  in one call. */
export const translationsPrompt = (
  works: readonly { key: string; work: ForeignWork }[],
  today: string,
  language: Language,
) => `Nous sommes le ${today}. Un lecteur a lu ces œuvres dans leur langue d'origine. Recherche sur le web leurs éditions en ${LANGUAGE_NAMES[language]}, déjà parues ET annoncées, en livre ET en livre audio :

${works.map(({ key, work }) => workLine(key, work)).join('\n')}

Renseigne works : une entrée par œuvre, avec sa clé exacte (key), translatedTitle et editions.
- translatedTitle : le nom de la série, ou le titre du livre, en ${LANGUAGE_NAMES[language]}, ou null si l'œuvre n'est pas traduite.
- editions : une entrée par tome et par format, la première édition en ${LANGUAGE_NAMES[language]} seulement. Pour chacune :
  - title : son titre en ${LANGUAGE_NAMES[language]}.
  - volume : son numéro dans la série, ou null.
  - format : 'book' pour un livre (papier ou numérique), 'audiobook' pour un livre audio.
  - date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA. Obligatoire pour une édition annoncée ; null pour une édition parue dont tu ne trouves pas la date.
  - language : la langue de cette édition, parmi ${BOOK_LANGUAGES.map((code) => `'${code}'`).join(', ')}.
  - isbn13 : son ISBN-13 si tu le trouves, sinon null. N'invente jamais un ISBN.

Ne liste que des éditions en ${LANGUAGE_NAMES[language]} confirmées par une source (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur). Une œuvre sans traduction revient avec editions vide. N'invente rien.`
