import type { Book, Genre } from '~/domain/book/types'
import { BOOK_LANGUAGES, GENRES } from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'
import type { ReleaseSubject } from './types'

/** Written into every prompt so the reasons come back in the reader's
 *  language, and the titles in the edition they would buy. */
const LANGUAGE_NAMES: Record<Language, string> = { fr: 'français', en: 'anglais' }

const bookLine = (book: Pick<Book, 'title' | 'authors'>) =>
  `« ${book.title} »${book.authors[0] ? ` de ${book.authors[0]}` : ''}`

const ITEM_RULES = (language: Language) => `Pour chaque livre :
- title : le titre sous lequel il est publié en ${LANGUAGE_NAMES[language]} s'il est traduit, sinon son titre original.
- authors : ses auteurs.
- year : l'année de première parution.
- isbn13 : l'ISBN-13 de l'édition en ${LANGUAGE_NAMES[language]} si tu le trouves, sinon null. N'invente jamais un ISBN.
- seriesName et volume : sa série et son numéro, ou null.
- genre : parmi ${GENRES.map((genre) => `'${genre}'`).join(', ')}.
- language : la langue du titre donné, parmi ${BOOK_LANGUAGES.map((code) => `'${code}'`).join(', ')}.
- synopsis : une à deux phrases, sans rien dévoiler.
- publicRating et ratingCount : la note moyenne des lecteurs sur 5 et leur nombre (Goodreads, Babelio, Amazon), ou null si tu ne les trouves pas.
- award : le prix majeur qu'il a reçu, sous la forme « Hugo 2024 », ou null.
- reason : UNE phrase courte, en ${LANGUAGE_NAMES[language]}, qui dit pourquoi CE lecteur l'aimerait, en citant ce qu'il a aimé.

Ne propose que des livres qui existent vraiment, vérifiés sur le web. Jamais un livre de la liste des livres déjà connus du lecteur.`

/** The reader's own shelves: what they loved, and what they would love next —
 *  including a genre they never touched, reached through one they love. */
export const personalPrompt = (input: {
  loved: readonly Book[]
  genres: readonly Genre[]
  known: readonly Pick<Book, 'title' | 'authors'>[]
  dismissed: readonly string[]
  language: Language
}) => `Tu es un libraire passionné. Recherche sur le web et propose des lectures à ce lecteur.

Livres qu'il a adorés (coup de cœur ou 5 étoiles) :
${input.loved.map((book) => `- ${bookLine(book)}${book.genre ? ` (${book.genre})` : ''}`).join('\n')}

Ses genres de prédilection : ${input.genres.join(', ') || 'inconnus'}.

Livres déjà connus du lecteur, à ne JAMAIS proposer :
${input.known.map((book) => `- ${bookLine(book)}`).join('\n')}
${input.dismissed.length > 0 ? `\nLivres qu'il a écartés, à ne jamais reproposer : ${input.dismissed.join(', ')}.\n` : ''}
Renseigne :
- becauseYouLoved : pour DEUX des livres qu'il a adorés (anchor : le titre exact tel qu'écrit ci-dessus), quatre livres dans la même veine, plébiscités par les lecteurs.
- offTrail : TROIS livres d'un genre ou d'un sous-genre qu'il ne lit JAMAIS, mais qui partagent quelque chose d'essentiel avec ce qu'il aime (par exemple : un lecteur de fantasy à progression de puissance comme Cradle découvrira le LitRPG avec Dungeon Crawler Carl). Pour ceux-là, reason explique le pont entre ce qu'il aime et ce genre nouveau.

${ITEM_RULES(input.language)}`

/** One genre's prize winners and most acclaimed books, shared by every reader
 *  of that genre in that language. */
export const genreListPrompt = (genre: Genre, language: Language) =>
  `Recherche sur le web les livres du genre '${genre}' qu'un lecteur ${language === 'fr' ? 'francophone' : 'anglophone'} doit connaître.

Renseigne :
- awards : HUIT livres récents (dix dernières années) lauréats d'un prix majeur du genre (par exemple Hugo, Nebula, Locus, World Fantasy, Grand Prix de l'Imaginaire, Bram Stoker, Edgar, Goncourt selon le genre). award est obligatoire pour ceux-là.
- acclaimed : HUIT livres parmi les mieux notés par les lecteurs du monde entier dans ce genre, avec beaucoup d'avis. publicRating et ratingCount sont obligatoires pour ceux-là.

Pour reason, dis en une phrase ce qui a fait son succès, sans parler du lecteur.

${ITEM_RULES(language)}`

const subjectLine = (key: string, subject: ReleaseSubject, language: Language) => {
  switch (subject.kind) {
    case 'series':
      return `- ${key} : la série « ${subject.name} »${subject.author ? ` de ${subject.author}` : ''} — les prochains tomes, en livre ET en livre audio.`
    case 'author':
      return `- ${key} : les prochains livres de ${subject.author}.`
    case 'translation':
      return `- ${key} : la traduction en ${LANGUAGE_NAMES[language]} de « ${subject.title} »${subject.author ? ` de ${subject.author}` : ''} et de ses suites, en livre ET en livre audio.`
  }
}

/** What comes out soon, for every subject of the watch list that needs a
 *  fresh look, in one call. */
export const releasesPrompt = (
  subjects: readonly { key: string; subject: ReleaseSubject }[],
  today: string,
  language: Language,
) => `Nous sommes le ${today}. Recherche sur le web les parutions annoncées ou récentes (depuis deux mois) pour chacun de ces sujets :

${subjects.map(({ key, subject }) => subjectLine(key, subject, language)).join('\n')}

Renseigne subjects : une entrée par sujet, avec sa clé exacte (key) et ses parutions (releases). Pour chaque parution :
- title : son titre dans la langue de cette parution.
- authors : ses auteurs.
- volume : son numéro dans la série, ou null.
- date : la date de parution la plus précise connue, au format AAAA-MM-JJ, sinon AAAA-MM, sinon AAAA.
- format : 'book' pour un livre (papier ou numérique), 'audiobook' pour un livre audio.
- language : la langue de cette parution, parmi ${BOOK_LANGUAGES.map((code) => `'${code}'`).join(', ')}.
- isbn13 : son ISBN-13 si tu le trouves, sinon null.

Ne liste que des parutions confirmées par une source (éditeur, libraire, Audible, annonce de l'auteur). Un sujet sans parution annoncée revient avec releases vide. N'invente rien.`
