import { BOOK_LANGUAGES, type BookLanguage } from '~/domain/book/types'
import type { WatchedWork } from './types'

/** Written into the prompt so the editions come back in the language asked. */
const LANGUAGE_NAMES: Record<BookLanguage, string> = {
  fr: 'français',
  en: 'anglais',
  es: 'espagnol',
  de: 'allemand',
  it: 'italien',
  pt: 'portugais',
  nl: 'néerlandais',
  sv: 'suédois',
  pl: 'polonais',
  ru: 'russe',
  uk: 'ukrainien',
  tr: 'turc',
  ar: 'arabe',
  ja: 'japonais',
  zh: 'chinois',
  ko: 'coréen',
}

const workLine = (work: WatchedWork) => {
  const author = work.author ? ` de ${work.author}` : ''
  return work.kind === 'series'
    ? `- ${work.key} : la série « ${work.title} »${author}, lue en '${work.readIn}' — CHAQUE tome, du tome 1 au dernier paru, puis ceux annoncés.`
    : `- ${work.key} : le livre « ${work.title} »${author}, lu en '${work.readIn}'.`
}

/** Every edition, out or announced, of one work in one language: its
 *  translation when the reader read it in another, its next volumes when they
 *  read it in that one. */
export const releasesPrompt = (work: WatchedWork, today: string) => {
  const language = LANGUAGE_NAMES[work.language]
  return `Nous sommes le ${today}. Un lecteur suit cette œuvre. Recherche sur le web ses éditions en ${language}, déjà parues ET annoncées, en livre ET en livre audio :

${workLine(work)}

Renseigne works : une entrée, avec sa clé exacte (key), translatedTitle et editions.
- translatedTitle : le nom de la série, ou le titre du livre, en ${language}, ou null si l'œuvre n'existe pas dans cette langue.
- editions : une entrée par tome et par format, la première édition en ${language} seulement. Pour une série, n'en saute aucun : le tome 1 comme le dernier, et chaque tome annoncé. Pour chacune :
  - title : son titre en ${language}.
  - volume : son numéro dans la série, ou null.
  - format : 'book' pour un livre (papier ou numérique), 'audiobook' pour un livre audio.
  - date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA. Obligatoire pour une édition annoncée ; null pour une édition parue dont tu ne trouves pas la date.
  - language : la langue de cette édition, parmi ${BOOK_LANGUAGES.map((code) => `'${code}'`).join(', ')}.
  - isbn13 : son ISBN-13 si tu le trouves, sinon null. N'invente jamais un ISBN.

Ne liste que des éditions en ${language} confirmées par une source (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur). Une œuvre sans édition dans cette langue revient avec editions vide. N'invente rien.`
}
