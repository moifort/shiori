import type { Language } from '~/domain/shared/language'

const languageNames = new Intl.DisplayNames(['fr'], { type: 'language' })

/** The narrator's catalogue. Runs once per narrator for the whole app, on the
 *  first opening of their page. Everything is written in the app's language. */
export const narratorPrompt = (name: string, language: Language) =>
  `Recherche sur le web ce narrateur de livres audio et renseigne sa fiche.

Narrateur : ${name}

C'est la voix qui lit des livres audio : souvent un comédien, parfois l'auteur lui-même ou un professionnel du doublage.

Renseigne :
- name : son nom tel qu'il est crédité sur les livres audio.
- nationality : sa nationalité, en un mot (« Français », « Américaine »), ou null si tu ne la trouves pas.
- birthYear, deathYear : ses années de naissance et de mort, ou null.
- biography : 2 à 3 phrases qui le présentent comme voix — son métier (comédien, doubleur…), ce qui l'a fait connaître, les livres audio, rôles ou voix françaises marquants. Rien sur sa vie privée. Null si tu ne trouves rien de fiable sur lui.
- wikipediaTitle : le titre EXACT de sa page sur Wikipédia en anglais (en.wikipedia.org), tel qu'il apparaît dans l'URL après /wiki/, ou null s'il n'en a pas. N'invente pas de page.

N'invente rien : un homonyme n'est pas lui, et un narrateur introuvable revient avec des valeurs null.

Toutes les valeurs textuelles doivent être en ${languageNames.of(language)}.`
