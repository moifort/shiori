import type { BookLanguage } from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'

const languageNames = new Intl.DisplayNames(['fr'], { type: 'language' })

/** The author's catalogue. Runs once per author for the whole app, on the first
 *  opening of their page, which is what makes it affordable to ask for the whole
 *  bibliography rather than a line of biography.
 *
 *  Titles are those of the edition the reader holds, as a saga's catalogue
 *  titles its volumes: a reader holding Sanderson in French looks for the French
 *  titles of what they lack. Everything else is written in the app's language. */
export const authorPrompt = (name: string, language: Language, editionLanguage?: BookLanguage) => {
  const edition = languageNames.of(editionLanguage ?? language)
  return `Recherche sur le web cet auteur et renseigne sa fiche.

Auteur : ${name}
Édition : en ${edition}. Les titres de séries et de livres sont ceux sous lesquels ils sont publiés en ${edition} — les titres traduits, jamais les titres originaux d'une autre langue. Un livre pas encore traduit garde son titre original.

Renseigne :
- name : le nom de l'auteur tel qu'il signe ses livres.
- nationality : sa nationalité, en un mot (« Américain », « Japonaise »), ou null si tu ne la trouves pas.
- birthYear, deathYear : ses années de naissance et de mort, ou null.
- biography : 2 à 3 phrases qui le présentent comme écrivain — ce qu'il écrit, ce qui l'a fait connaître. Rien sur sa vie privée.
- wikipediaTitle : le titre EXACT de sa page sur Wikipédia en anglais (en.wikipedia.org), tel qu'il apparaît dans l'URL après /wiki/, ou null s'il n'en a pas. N'invente pas de page.
- series : TOUTES ses séries publiées, dans l'ordre de publication. Pour chacune : name, son nom ; volumeCount, le nombre de tomes principaux parus ou annoncés ; firstVolumeTitle, le titre du premier tome.
- books : ses livres publiés qui n'appartiennent à AUCUNE série, dans l'ordre de publication. Pour chacun : title et publishedIn, l'année de parution. Un tome d'une série n'est JAMAIS ici.

N'invente rien pour compléter : un auteur dont tu ne connais que trois livres n'en a que trois. Un auteur introuvable revient avec des tableaux vides.

En dehors des titres, toutes les valeurs textuelles doivent être en ${languageNames.of(language)}.`
}
