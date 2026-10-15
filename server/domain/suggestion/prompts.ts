import type { BookFormat, BookLanguage } from '~/domain/book/types'
import { LANGUAGE_NAMES } from '~/domain/discovery/prompts'
import type { Language } from '~/domain/shared/language'
import { ASKED_COUNT } from './business-rules'

const FORMAT_NAMES: Record<BookFormat, string> = {
  book: 'livres papier ou numériques',
  audiobook: 'livres audio',
  'bande-dessinee': 'bandes dessinées',
  comic: 'comics',
  manga: 'mangas',
}

type Profile = {
  formats: { value: BookFormat; share: number }[]
  languages: { value: BookLanguage; share: number }[]
}

const percent = (share: number) => `${Math.round(share * 100)} %`

/** What the reader reads in their own language: the word the line under the
 *  cover starts with, and how the reason speaks to them. */
const VOICE: Record<Language, { like: string; tone: string }> = {
  fr: { like: 'comme', tone: 'qui tutoie le lecteur' },
  en: { like: 'like', tone: 'qui s’adresse au lecteur par « you »' },
}

/** What the model is asked: the library by tier, how the reader reads, and
 *  the twenty books it would put in their hands, each with why. Written the
 *  way the blind test of 2026-10-12 asked it, which three readers found worth
 *  having; the reason and the line under the cover come back in the app's
 *  language. */
export const suggestionsPrompt = (digest: string, profile: Profile, appLanguage: Language) => {
  const formats = profile.formats
    .slice(0, 3)
    .map(({ value, share }) => `${FORMAT_NAMES[value]} (${percent(share)})`)
    .join(', ')
  const languages = profile.languages
    .slice(0, 2)
    .map(({ value, share }) => `${LANGUAGE_NAMES[value]} (${percent(share)})`)
    .join(', ')
  const written = LANGUAGE_NAMES[appLanguage]
  const { like, tone } = VOICE[appLanguage]
  return `Tu es un libraire passionné et très cultivé : romans, science-fiction, fantasy, LitRPG, polar, thriller, romance, essais, histoire, BD franco-belge, comics et manga. Voici la bibliothèque d'un lecteur, rangée par paliers : ses coups de cœur, ses 5, 4 et 3 étoiles, ce qui l'a déçu, ce qu'il a abandonné, et les suggestions qu'il a déjà refusées. Un tome sans note prend celle de sa série.

Il lit surtout : ${formats}. En ${languages}. Propose des livres qu'il peut avoir dans ces formats, disponibles en ${written} de préférence.

Propose ${ASKED_COUNT} livres qu'il n'a PAS dans sa bibliothèque et qui ont de fortes chances de lui plaire. Pas de tome suivant d'une saga qu'il lit déjà : il les connaît. Rien de ce qu'il a refusé. Évite les évidences qu'un lecteur de ce profil a forcément croisées ; vise juste plutôt que large. Tiens compte de ses abandons et de ses déceptions pour savoir ce qui ne lui plaît pas. Ne propose que des livres qui existent : en cas de doute sur un titre ou un auteur, choisis-en un autre.

Le titre, la raison et la ligne courte sont écrits en ${written}, quelle que soit la langue de ce message.

Réponds UNIQUEMENT par un tableau JSON, sans texte autour, de ${ASKED_COUNT} objets, le plus sûr d'abord :
{"title": titre de l'édition en ${written} si elle existe, sinon le titre original, "originalTitle": titre original, "author": auteur (plusieurs séparés par des virgules), "language": code ISO 639-1 de la langue d'écriture, "kind": "novel" | "essay" | "comic" | "manga", "reason": une phrase de 25 mots au plus, en ${written}, ${tone}, qui dit pourquoi en citant un livre ou une série de sa bibliothèque, "short": "${like} " suivi du titre court du livre ou de la série cité, en ${written}, "references": les titres exacts, tels qu'écrits ci-dessous, des livres ou séries de sa bibliothèque cités}

Bibliothèque :

${digest}`
}
