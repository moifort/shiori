import type { BookLanguage } from '~/domain/book/types'
import type { ScanLanguage, ScanResult } from '~/domain/scan/types'
import { VOLUME_KINDS } from '~/domain/series/types'

/** The language name is written into the prompt so Gemini emits every free-text
 *  value in the caller's language — a French reader gets a French synopsis of an
 *  English novel, not the publisher's blurb. */
const LANGUAGE_NAMES: Record<ScanLanguage, string> = {
  fr: 'français',
  en: 'anglais',
}

/** Step 1 — what the camera can see. Deliberately narrow: it asks only for what
 *  is printed on the cover, and forbids inference. Everything the cover does not
 *  say is step 2's job, where the model can actually look it up instead of
 *  guessing, and where a wrong guess is correctable against a source. */
export const visionPrompt = (language: ScanLanguage) =>
  `Analyse cette photo de couverture de livre et extrais uniquement ce qui y est IMPRIMÉ.

ÉTAPE 0 — Détermine recognized : mets recognized=false et title="" si l'image n'est PAS une couverture de livre identifiable (aucun texte lisible, objet quelconque, photo floue). Ne mets recognized=false que si tu ne peux vraiment rien lire.

ÉTAPE 0 bis — Détermine format, la nature de l'objet, d'après ce que montre la couverture : 'manga' pour un manga (sens de lecture japonais, dessin manga, éditeur comme Glénat Manga, Kana, Pika), 'bande-dessinee' pour un album de bande dessinée franco-belge, 'comic' pour un comic américain ou un roman graphique de cette tradition, 'audiobook' pour un livre audio (boîtier de CD, mention « livre audio »), 'ebook' pour une couverture affichée sur une liseuse ou un écran, 'book' pour tout autre livre. Mets null si tu hésites entre plusieurs.

ÉTAPE 1 — Relève le titre tel qu'il apparaît, sans le compléter ni le corriger. Un sous-titre sur une ligne distincte ne fait pas partie du titre.

ÉTAPE 2 — Relève le ou les auteurs. Ignore les mentions de traducteur, de préfacier et d'illustrateur : ce ne sont pas des auteurs.

ÉTAPE 3 — Relève l'éditeur si son nom ou son logo est lisible, sinon null.

ÉTAPE 3 bis — Détermine language, la langue de CETTE édition, d'après la langue du titre et des textes imprimés sur la couverture. C'est la langue de l'objet photographié, pas celle de l'œuvre d'origine : une traduction française de Dune a language='fr'. Mets null si la couverture ne permet pas de trancher, ou si la langue ne figure pas dans la liste proposée.

ÉTAPE 4 — Relève la série si la couverture la mentionne. Les couvertures de livres l'affichent souvent explicitement (« Tome 3 », « Livre II », « Volume 2 », « Cycle de… »). Renseigne seriesName avec le nom de la série SEUL, sans le numéro, et volumeNumber avec le chiffre. Si rien n'indique une série, mets les deux à null — ne déduis pas une série d'un titre qui y ressemble.

N'INVENTE RIEN. Si une information n'est pas visible sur l'image, mets null. Toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`

/** What step 1 read off the cover that step 2 needs to name the edition, not
 *  merely the work: the reader owns one object, and its ISBN is that object's. */
type EditionSeen = Pick<ScanResult, 'title' | 'authors' | 'publisher' | 'language'>

const languageNames = new Intl.DisplayNames(['fr'], { type: 'language' })

/** The edition the reader holds, as precisely as the cover said. A typed title
 *  has no publisher, so it falls back to an edition in the reader's language. */
const editionOf = (publisher: string | undefined, language: string) =>
  `Édition : ${publisher ? `éditeur « ${publisher} », ` : ''}en ${languageNames.of(language)}. C'est de CETTE édition que parlent pageCount et isbn13.`

/** Step 2 — what the web knows. This is where grounding earns its cost: series
 *  membership in particular is what the cover conveys badly or not at all, and
 *  it is what the whole series feature is built on. */
export const enrichmentPrompt = (
  { title, authors, publisher, language: editionLanguage }: EditionSeen,
  language: ScanLanguage,
  source: 'cover' | 'typed' = 'cover',
) =>
  `${source === 'typed' ? TYPED_TITLE_PREFACE : ''}Recherche sur le web les informations de ce livre et renseigne la fiche.

Livre : « ${title} »${authors.length > 0 ? ` de ${authors.join(', ')}` : ''}
${editionOf(publisher, editionLanguage ?? language)}

Renseigne :
- title et authors : corrige-les si la recherche montre que la lecture de la couverture était fautive, sinon reprends-les tels quels.
- synopsis : un résumé de 3 à 5 phrases, SANS révéler le dénouement.
- firstPublishedIn : l'année de première publication de l'ŒUVRE, pas de cette édition.
- genre : UN SEUL genre, choisi dans la liste imposée par le schéma : le plus précis qui convienne au contenu. Le format de l'objet (manga, BD) et le public visé (jeunesse, young adult) ne sont pas des genres. Mets other si aucun ne convient.
- subgenres : de 0 à 3 sous-genres libres qui précisent le genre (« dark fantasy », « space opera », « shōnen », « jeunesse »), écrits en ${languageNames.of(editionLanguage ?? language)}, la langue de cette édition — ce champ fait exception à la règle de langue ci-dessous. Classe-les du plus représentatif au moins représentatif : le premier doit être celui qui décrit le mieux ce livre, car c'est le seul que le lecteur verra dans sa liste. Ne répète pas le genre.
- pageCount : le nombre de pages de CETTE édition, ou null.
- isbn13 : l'ISBN-13 de CETTE édition. Un même livre a souvent plusieurs éditions dans une même langue (grand format, poche, édition québécoise ou belge) : l'ISBN d'une autre édition est faux ici, même s'il existe. Mets null si tu ne trouves pas celui de cette édition précise — un ISBN inventé ou celui d'une autre édition est pire qu'un ISBN absent, car il sert à retrouver la couverture de l'objet que le lecteur possède.
- seriesName, volumeNumber, volumeKind : la série à laquelle ce livre appartient. C'est l'information la plus importante de cette fiche. Cherche-la activement : beaucoup de romans appartiennent à un cycle sans que la couverture le dise. volumeKind vaut 'main' pour un tome numéroté de l'histoire principale, 'prequel' pour une préquelle, 'spin-off' pour un récit dérivé, 'novella' pour un texte court rattaché, 'companion' pour un guide ou un artbook. Si le livre est indépendant, mets les trois à null.

Toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`

/** A title the reader typed is not a title read off a cover: it can be
 *  approximate, partial, or misspelt, and the model has nothing else to go on.
 *  Said up front, so it looks for the most likely book rather than the exact
 *  string. */
const TYPED_TITLE_PREFACE = `Le titre ci-dessous a été saisi de mémoire par le lecteur, pas lu sur une couverture : il peut être approximatif, partiel ou mal orthographié. Retrouve le livre le plus probable et renseigne sa fiche avec son titre exact.

`

/** Step 3 — the saga's catalogue. Runs once per series for the whole app, not
 *  once per reader, which is what makes it affordable to ask for the complete
 *  list rather than just the next volume.
 *
 *  The volumes are titled as the edition on the shelf titles them: a reader
 *  holding a saga in French looks for the French titles of its sequels, and
 *  asked for "French text" alone the model kept the original English ones as
 *  if they were names. The edition is the one read off the cover or held in
 *  the library; the reader's own language stands in when it is unknown. */
export const cataloguePrompt = (
  seriesName: string,
  author: string,
  language: ScanLanguage,
  editionLanguage?: BookLanguage,
) => {
  const edition = languageNames.of(editionLanguage ?? language)
  return `Recherche sur le web la liste COMPLÈTE des volumes de cette série et renseigne son catalogue.

Série : « ${seriesName} » de ${author}
Édition : en ${edition}. C'est de CETTE édition que parle le catalogue : le nom de la série et les titres des volumes sont ceux sous lesquels ils sont publiés en ${edition} — les titres traduits, jamais les titres originaux d'une autre langue. Un volume pas encore traduit garde son titre original.

Renseigne :
- name et author : le nom de la série et son auteur principal.
- description : 2 à 3 phrases présentant la série, SANS révéler le dénouement.
- volumes : TOUS les volumes publiés ou annoncés, dans l'ordre de PUBLICATION. Pour chacun :
  - number : le numéro du tome dans l'histoire principale, ou null pour tout ce qui est hors numérotation.
  - title : le titre du volume dans l'édition en ${edition}.
  - publishedIn : l'année de parution. Pour un volume annoncé mais pas encore paru, indique l'année annoncée — c'est une information utile, ne l'omets pas.
  - kind : ${VOLUME_KINDS.map((kind) => `'${kind}'`).join(', ')}. 'main' pour un tome numéroté de l'histoire principale, 'prequel' pour une préquelle, 'spin-off' pour un récit dérivé, 'novella' pour un texte court, 'companion' pour un guide, un atlas ou un artbook.

N'invente pas de volumes pour compléter une série : si tu n'en connais que quatre, n'en liste que quatre. Une série inexistante ou introuvable doit revenir avec un tableau volumes vide.

En dehors des titres, toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`
}
