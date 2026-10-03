import type { BookLanguage } from '~/domain/book/types'
import { AMAZON_STORES } from '~/domain/shared/amazon-stores'
import { AUDIBLE_STORES } from '~/domain/shared/audible-stores'
import { formatOf } from './business-rules'
import type { SagaWatch, WatchedAuthor } from './types'

/** Written into the prompt so the volumes come back in the language asked. */
export const LANGUAGE_NAMES: Record<BookLanguage, string> = {
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
    : `en livre (papier ou numérique), tels que la boutique Amazon de cette langue (${AMAZON_STORES[saga.language] ?? 'Amazon'}) les liste`
  return `Nous sommes le ${today}. Un lecteur suit la série « ${saga.name} »${author} en ${language}. Recherche sur le web CHACUN de ses tomes parus en ${language} ${format}, du tome 1 au dernier paru, puis ceux annoncés.

Renseigne volumes : une entrée par tome numéroté de la série, la première édition en ${language} seulement. N'en saute aucun. Pour chacun :
- number : son numéro dans la série.
- title : son titre en ${language}, sans le nom de la série ni le numéro du tome.
- date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA. Obligatoire pour un tome annoncé ; null pour un tome paru dont tu ne trouves pas la date.
- isbn13 : l'ISBN-13 de cette édition en ${language}, celui de sa fiche sur la boutique Amazon de cette langue de préférence, sinon null. N'invente jamais un ISBN.${
    audio
      ? `
- asin : l'identifiant Audible de l'enregistrement (dix caractères, par exemple B0DM67WR2V), lu dans l'adresse de sa page sur ${store}, sinon null. N'invente jamais un ASIN.`
      : ''
  }

Ne liste que des tomes confirmés par une source (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur). Une série sans tome dans cette langue revient avec volumes vide. N'invente rien.`
}

/** Every book of one author, out in the last months or announced, in one
 *  language and one format: the works the Authors shelf of Découvrir is read
 *  off. */
export const authorReleasesPrompt = (author: WatchedAuthor, today: string, since: string) => {
  const language = LANGUAGE_NAMES[author.language]
  const audio = author.format === 'audiobook'
  const store = AUDIBLE_STORES[author.language] ?? 'Audible'
  const format = audio
    ? `en livre audio, tels que le catalogue Audible de cette langue (${store}) les liste`
    : `en livre (papier ou numérique), tels que la boutique Amazon de cette langue (${AMAZON_STORES[author.language] ?? 'Amazon'}) les liste`
  return `Nous sommes le ${today}. Un lecteur suit l'auteur ${author.name} en ${language}. Recherche sur le web CHACUN de ses livres parus en ${language} ${format} depuis le ${since}, puis ceux annoncés.

Renseigne works : une entrée par livre, la première édition en ${language} seulement, rééditions et intégrales exclues. Pour chacun :
- title : son titre en ${language}.
- date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA. Obligatoire.
- isbn13 : l'ISBN-13 de cette édition en ${language}, celui de sa fiche sur la boutique Amazon de cette langue de préférence, sinon null. N'invente jamais un ISBN.${
    audio
      ? `
- asin : l'identifiant Audible de l'enregistrement (dix caractères, par exemple B0DM67WR2V), lu dans l'adresse de sa page sur ${store}, sinon null. N'invente jamais un ASIN.`
      : ''
  }
- series : le nom de la série dont il est un tome, tel que l'éditeur l'écrit en ${language}, sinon null.
- volume : son numéro dans cette série, sinon null.

Ne liste que des livres de ${author.name} confirmés par une source (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur). Un auteur sans parution récente ni annonce dans cette langue revient avec works vide. N'invente rien.`
}
