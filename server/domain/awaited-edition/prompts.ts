import { LANGUAGE_NAMES } from '~/domain/discovery/prompts'
import { AMAZON_STORES } from '~/domain/shared/amazon-stores'
import { AUDIBLE_STORES } from '~/domain/shared/audible-stores'
import type { EditionWatch } from './types'

/** One book's edition in one language and one format: its translation into
 *  print, or its recording, out or announced. The saga it belongs to is named
 *  as a clue, since a translation often carries another title. */
export const editionPrompt = (
  watch: Pick<
    EditionWatch,
    'title' | 'author' | 'originalLanguage' | 'series' | 'format' | 'language'
  >,
  today: string,
) => {
  const language = LANGUAGE_NAMES[watch.language]
  const author = watch.author ? ` de ${watch.author}` : ''
  const saga = watch.series
    ? `, ${watch.series.volume !== undefined ? `tome ${watch.series.volume} de` : 'de'} la série « ${watch.series.name} »`
    : ''
  const audio = watch.format === 'audiobook'
  const store = AUDIBLE_STORES[watch.language] ?? 'Audible'
  const format = audio
    ? `en livre audio, tel que le catalogue Audible de cette langue (${store}) le liste`
    : `en livre (papier ou numérique), tel que la boutique Amazon de cette langue (${AMAZON_STORES[watch.language] ?? 'Amazon'}) le liste`
  return `Nous sommes le ${today}. Un lecteur connaît « ${watch.title} »${author}, en ${LANGUAGE_NAMES[watch.originalLanguage]}${saga}. Il attend sa parution en ${language} ${format}. Recherche sur le web si cette édition en ${language} existe déjà ou est annoncée.

Renseigne found : true si une source confirme cette édition (éditeur, libraire, Audible, annonce de l'auteur ou du traducteur), false sinon. Si found est true :
- title : son titre en ${language}, qui peut différer du titre original.
- date : sa date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA ; null si elle est annoncée sans date.
- isbn13 : l'ISBN-13 de cette édition en ${language}, celui de sa fiche sur la boutique Amazon de cette langue de préférence, sinon null. N'invente jamais un ISBN.${
    audio
      ? `
- asin : l'identifiant Audible de l'enregistrement (dix caractères, par exemple B0DM67WR2V), lu dans l'adresse de sa page sur ${store}, sinon null. N'invente jamais un ASIN.`
      : ''
  }

Ne confonds pas avec une autre édition dans la langue originale, un résumé, une étude ou un autre livre de l'auteur. N'invente rien.`
}
