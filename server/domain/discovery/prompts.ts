import type { BookLanguage } from '~/domain/book/types'
import { AUDIBLE_STORES } from '~/domain/shared/audible-stores'
import { formatOf } from './business-rules'
import type { SagaWatch } from './types'

/** Written into the prompt so the volumes come back in the language asked. */
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

/** Every volume, out or announced, of one saga in one language and one
 *  format: its printed books for a saga read, its recordings for a saga heard. */
export const releasesPrompt = (
  saga: Pick<SagaWatch, 'seriesId' | 'name' | 'author' | 'language'>,
  today: string,
) => {
  const language = LANGUAGE_NAMES[saga.language]
  const author = saga.author ? ` de ${saga.author}` : ''
  const audio = formatOf(saga.seriesId) === 'audiobook'
  const store = AUDIBLE_STORES[saga.language] ?? 'Audible'
  const format = audio
    ? `en livre audio, tels que le catalogue Audible de cette langue (${store}) les liste`
    : 'en livre (papier ou numérique)'
  return `Nous sommes le ${today}. Un lecteur suit la série « ${saga.name} »${author} en ${language}. Recherche sur le web CHACUN de ses tomes parus en ${language} ${format}, du tome 1 au dernier paru, puis ceux annoncés.

Renseigne volumes : une entrée par tome numéroté de la série, la première édition en ${language} seulement. N'en saute aucun. Pour chacun :
- number : son numéro dans la série.
- title : son titre en ${language}.
- date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA. Obligatoire pour un tome annoncé ; null pour un tome paru dont tu ne trouves pas la date.
- isbn13 : son ISBN-13 si tu le trouves, sinon null. N'invente jamais un ISBN.${
    audio
      ? `
- asin : l'identifiant Audible de l'enregistrement (dix caractères, par exemple B0DM67WR2V), lu dans l'adresse de sa page sur ${store}, sinon null. N'invente jamais un ASIN.`
      : ''
  }

Ne liste que des tomes confirmés par une source (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur). Une série sans tome dans cette langue revient avec volumes vide. N'invente rien.`
}
