import type { BookFormat, BookLanguage } from '~/domain/book/types'
import type { EditionHints, ScanLanguage, ScanResult } from '~/domain/scan/types'
import { VOLUME_KINDS, type VolumeKind } from '~/domain/series/types'
import { AUDIBLE_STORES } from '~/domain/shared/audible-stores'

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
 *  merely the work: the reader owns one object, and its ISBN is that object's.
 *  The saga and the format too, when known: the volumes of a comic are often
 *  all titled after it, and the title alone named volume 1 for every one. */
type EditionSeen = Pick<
  ScanResult,
  'title' | 'authors' | 'publisher' | 'language' | 'format' | 'series'
>

const languageNames = new Intl.DisplayNames(['fr'], { type: 'language' })

/** The edition the reader holds, as precisely as the cover said. A typed title
 *  has no publisher, so it falls back to an edition in the reader's language. */
const editionOf = (publisher: string | undefined, language: string) =>
  `Édition : ${publisher ? `éditeur « ${publisher} », ` : ''}en ${languageNames.of(language)}. C'est de CETTE édition que parlent pageCount et isbn13.`

/** What the object is, said to the model when it is not a plain book: a comic
 *  and the novel it was drawn from share a title, never an ISBN. */
const FORMAT_NAMES: Record<Exclude<BookFormat, 'book'>, string> = {
  audiobook: 'livre audio',
  'bande-dessinee': 'bande dessinée',
  comic: 'comic',
  manga: 'manga',
}

const formatLineOf = (format: BookFormat | undefined) =>
  format && format !== 'book' ? `Format : ${FORMAT_NAMES[format]}.\n` : ''

const KIND_NAMES: Record<Exclude<VolumeKind, 'main'>, string> = {
  prequel: 'préquelle',
  'spin-off': 'récit dérivé',
  novella: 'texte court',
  companion: 'guide ou artbook',
}

/** The volume, when the cover printed it or the catalogue knows it. */
const sagaLineOf = (series: ScanResult['series']) => {
  if (!series) return ''
  const volume = series.volume !== undefined ? `, tome ${series.volume}` : ''
  const kind = series.kind !== 'main' ? ` (${KIND_NAMES[series.kind]})` : ''
  return `Série : « ${series.name} »${volume}${kind}. C'est CE tome qu'il faut renseigner : les tomes d'une série portent souvent le même titre, mais ni le même ISBN, ni la même couverture, ni le même nombre de pages.\n`
}

/** What the catalogue and the reader's shelf already say of the volume. */
const hintLinesOf = (hints: EditionHints | undefined) => {
  if (!hints) return ''
  const lines: string[] = []
  if (hints.watchedIsbn13)
    lines.push(
      `ISBN relevé pour ce tome par notre veille des parutions : ${hints.watchedIsbn13}. Vérifie-le : reprends-le s'il désigne bien ce tome dans cette édition, sinon cherche le bon.`,
    )
  if (hints.releasedOn)
    lines.push(
      `Parution de ce tome dans cette édition, d'après notre veille : ${hints.releasedOn}.`,
    )
  if (hints.siblings.length > 0) {
    const listed = hints.siblings
      .map(({ volume, kind, isbn13 }) =>
        volume !== undefined && kind === 'main'
          ? `${isbn13} (tome ${volume})`
          : `${isbn13} (${kind === 'main' ? 'autre tome' : KIND_NAMES[kind]})`,
      )
      .join(', ')
    lines.push(
      `ISBN d'autres tomes de la même série, qui ne sont donc PAS celui de ce tome : ${listed}. Ils indiquent aussi l'éditeur et la collection à chercher.`,
    )
  }
  return lines.map((line) => `${line}\n`).join('')
}

/** Step 2 — what the web knows. This is where grounding earns its cost: series
 *  membership in particular is what the cover conveys badly or not at all, and
 *  it is what the whole series feature is built on. */
export const enrichmentPrompt = (
  { title, authors, publisher, language: editionLanguage, format, series }: EditionSeen,
  language: ScanLanguage,
  source: 'cover' | 'typed' = 'cover',
  hints?: EditionHints,
) =>
  `${source === 'typed' ? TYPED_TITLE_PREFACE : ''}Recherche sur le web les informations de ce livre et renseigne la fiche.

Livre : « ${title} »${authors.length > 0 ? ` de ${authors.join(', ')}` : ''}
${sagaLineOf(series)}${formatLineOf(format)}${hintLinesOf(hints)}${editionOf(publisher, editionLanguage ?? language)}

Renseigne :
- title et authors : corrige-les si la recherche montre que la lecture de la couverture était fautive, sinon reprends-les tels quels. Le titre est celui du livre SEUL, sans le nom de la série ni le numéro du tome, qui ont leurs propres champs ; un tome sans titre propre porte le nom de la série.
- synopsis : un résumé de 3 à 5 phrases, SANS révéler le dénouement.
- firstPublishedIn : l'année de première publication de l'ŒUVRE, pas de cette édition.
- genre : UN SEUL genre, choisi dans la liste imposée par le schéma : le plus précis qui convienne au contenu. Le format de l'objet (manga, BD) et le public visé (jeunesse, young adult) ne sont pas des genres. Mets other si aucun ne convient.
- subgenres : de 0 à 3 sous-genres libres qui précisent le genre (« dark fantasy », « space opera », « shōnen », « jeunesse »), écrits en ${languageNames.of(editionLanguage ?? language)}, la langue de cette édition — ce champ fait exception à la règle de langue ci-dessous. Classe-les du plus représentatif au moins représentatif : le premier doit être celui qui décrit le mieux ce livre, car c'est le seul que le lecteur verra dans sa liste. Ne répète pas le genre.
- pageCount : le nombre de pages de CETTE édition, ou null.
- isbn13 : l'ISBN-13 de CETTE édition. Un même livre a souvent plusieurs éditions dans une même langue (grand format, poche, édition québécoise ou belge) : l'ISBN d'une autre édition est faux ici, même s'il existe. Mets null si tu ne trouves pas celui de cette édition précise — un ISBN inventé ou celui d'une autre édition est pire qu'un ISBN absent, car il sert à retrouver la couverture de l'objet que le lecteur possède.
- regularEditionIsbn13 : seulement si CETTE édition est une édition spéciale (collector, limitée, de luxe, reliée à tranche décorée ou jaspage, coffret) : l'ISBN-13 de l'édition courante du même livre, chez le même éditeur et dans la même langue. Il sert uniquement à afficher une couverture à plat, car celle d'une édition spéciale est souvent une photo de l'objet en perspective. Mets null pour une édition courante, ou si tu ne trouves pas cet ISBN avec certitude.
- seriesName, volumeNumber, volumeKind : la série à laquelle ce livre appartient. C'est l'information la plus importante de cette fiche. Cherche-la activement : beaucoup de romans appartiennent à un cycle sans que la couverture le dise. volumeNumber est le numéro du tome dans toute la série, même quand la couverture imprime celui de son cycle : si le premier cycle compte trois tomes, « cycle 2, tome 2 » est le tome 5. volumeKind vaut 'main' pour un tome numéroté de l'histoire principale, 'prequel' pour une préquelle, 'spin-off' pour un récit dérivé, 'novella' pour un texte court rattaché, 'companion' pour un guide ou un artbook. Si le livre est indépendant, mets les trois à null.

Toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`

/** A title the reader typed is not a title read off a cover: it can be
 *  approximate, partial, or misspelt, and the model has nothing else to go on.
 *  Said up front, so it looks for the most likely book rather than the exact
 *  string. */
const TYPED_TITLE_PREFACE = `Le titre ci-dessous a été saisi de mémoire par le lecteur, pas lu sur une couverture : il peut être approximatif, partiel ou mal orthographié. Retrouve le livre le plus probable et renseigne sa fiche avec son titre exact.

`

/** How many books the reader is offered at most: past five, the right one is
 *  better found by typing a few more words. */
export const MAX_CANDIDATES = 5

/** The step before a typed title is looked up: which books the reader may mean.
 *  Not grounded — the model's own knowledge tells "Fondation" the novel from
 *  "Fondation" the cycle in a few seconds, and the grounded lookup that follows
 *  checks the one picked against the web anyway. */
export const candidatesPrompt = (title: string, language: ScanLanguage) =>
  `Un lecteur a saisi de mémoire ce texte pour retrouver un livre : « ${title} »

Le texte peut être approximatif, partiel ou mal orthographié, et peut contenir un nom d'auteur. Liste les livres DISTINCTS auxquels il peut correspondre, le plus probable en premier, ${MAX_CANDIDATES} au plus.

- Ne propose que des livres qui existent réellement. N'invente rien.
- Si le texte désigne sans ambiguïté un seul livre, ne renvoie que celui-là.
- Deux éditions ou traductions d'une même œuvre sont UN SEUL livre : ne les liste pas séparément.
- Des tomes différents d'une même série sont des livres distincts.
- title : le titre exact, dans l'édition en ${LANGUAGE_NAMES[language]} si elle existe, sans le nom de la série ni le numéro du tome.
- seriesName et volumeNumber : la série et le numéro de tome, sinon null.
- Si aucun livre ne correspond, renvoie une liste vide.`

/** Step 3 — the saga's catalogue. Runs once per series for the whole app, not
 *  once per reader, which is what makes it affordable to ask for the complete
 *  list rather than just the next volume.
 *
 *  Only the volumes already out in the edition's language: what is announced,
 *  or out in another language only, is the release watch's to find, per
 *  language and with a date, in Découvrir's hourly pass. A scan that listed
 *  them made an untranslated volume count as out until that pass came by, on
 *  nothing more than the year it came out elsewhere.
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
Édition : en ${edition}. C'est de CETTE édition que parle le catalogue : le nom de la série et les titres des volumes sont ceux sous lesquels ils sont publiés en ${edition} — les titres traduits, jamais les titres originaux d'une autre langue.

Renseigne :
- name et author : le nom de la série et son auteur principal.
- description : 2 à 3 phrases présentant la série, SANS révéler le dénouement.
- volumes : TOUS les volumes DÉJÀ PARUS en ${edition}, dans l'ordre de PUBLICATION. Un volume annoncé mais pas encore paru n'en fait PAS partie, ni un volume paru dans une autre langue mais pas encore traduit en ${edition} : ne les liste pas. Pour chacun :
  - number : le numéro du tome dans l'histoire principale, ou null pour tout ce qui est hors numérotation. Une série publiée en cycles se numérote d'un bout à l'autre : si le premier cycle compte trois tomes, « cycle 2, tome 2 » est le tome 5.
  - title : le titre du volume dans l'édition en ${edition}, sans le nom de la série ni le numéro du tome ; un tome sans titre propre porte le nom de la série.
  - publishedIn : l'année de parution en ${edition}, pas celle de l'édition originale.
  - kind : ${VOLUME_KINDS.map((kind) => `'${kind}'`).join(', ')}. 'main' pour un tome numéroté de l'histoire principale, 'prequel' pour une préquelle, 'spin-off' pour un récit dérivé, 'novella' pour un texte court, 'companion' pour un guide, un atlas ou un artbook.

N'invente pas de volumes pour compléter une série : si tu n'en connais que quatre, n'en liste que quatre. Une série inexistante, introuvable ou sans aucun volume paru en ${edition} doit revenir avec un tableau volumes vide.

En dehors des titres, toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`
}

/** Step 3 for a saga heard rather than read: the volumes recorded, not the
 *  volumes printed. A recording trails its book, sometimes by years, and some
 *  are never made — so a volume out in print only is left out, and the saga's
 *  spine is the one its listener can actually follow. A recording announced
 *  but not out is left to the release watch, as for a saga read. The recordings are looked
 *  up on the Audible store of the edition's language, where they are listed. */
export const audioCataloguePrompt = (
  seriesName: string,
  author: string,
  language: ScanLanguage,
  editionLanguage?: BookLanguage,
) => {
  const code = editionLanguage ?? language
  const edition = languageNames.of(code)
  return `Recherche sur le web la liste des volumes de cette série ENREGISTRÉS EN LIVRE AUDIO en ${edition}, et renseigne son catalogue.

Série : « ${seriesName} » de ${author}
Édition : le livre audio en ${edition}. C'est de CET enregistrement que parle le catalogue, pas des livres imprimés : cherche tome par tome dans le catalogue Audible de cette langue (${AUDIBLE_STORES[code] ?? 'Audible'}). Le nom de la série et les titres des volumes sont ceux sous lesquels les enregistrements sont publiés en ${edition}.

Renseigne :
- name et author : le nom de la série et son auteur principal.
- description : 2 à 3 phrases présentant la série, SANS révéler le dénouement.
- volumes : les volumes enregistrés en livre audio en ${edition} DÉJÀ SORTIS, dans l'ordre de PUBLICATION. Un tome paru en livre imprimé mais pas encore enregistré en ${edition} n'en fait PAS partie, ni un enregistrement annoncé mais pas encore sorti : ne les liste pas. Pour chacun :
  - number : le numéro du tome dans l'histoire principale, ou null pour tout ce qui est hors numérotation. Une série publiée en cycles se numérote d'un bout à l'autre : si le premier cycle compte trois tomes, « cycle 2, tome 2 » est le tome 5.
  - title : le titre de l'enregistrement en ${edition}, sans le nom de la série ni le numéro du tome ; un tome sans titre propre porte le nom de la série.
  - publishedIn : l'année de sortie du livre audio, pas celle du livre imprimé.
  - kind : ${VOLUME_KINDS.map((kind) => `'${kind}'`).join(', ')}. 'main' pour un tome numéroté de l'histoire principale, 'prequel' pour une préquelle, 'spin-off' pour un récit dérivé, 'novella' pour un texte court, 'companion' pour un guide, un atlas ou un artbook.

Le nom de la série et les titres des volumes sont des titres d'œuvre, pas des intitulés de fiche Audible : retire-leur toute mention d'édition ou de format, comme « (French edition) », « (Édition française) », « (Unabridged) », « Version intégrale », « Livre audio », « Audiobook », ou le numéro de tome placé entre parenthèses à la suite du titre.

Un livre audio découpé en plusieurs parties reste un seul volume. N'invente pas de volumes : si tu ne trouves que trois enregistrements, n'en liste que trois. Une série sans aucun enregistrement en ${edition} doit revenir avec un tableau volumes vide.

En dehors des titres, toutes les valeurs textuelles doivent être en ${LANGUAGE_NAMES[language]}.`
}

/** A whole shelf in one photo: spines side by side, or covers laid out flat.
 *  As narrow as `visionPrompt` — only what is printed — and just as honest about
 *  what it cannot read: an unreadable spine is still a book, framed with no
 *  title, so the reader can name it rather than lose it. */
export const shelfPrompt = (language: ScanLanguage) =>
  `Cette photo montre plusieurs livres : des tranches alignées sur une étagère, ou des couvertures posées à plat. Repère CHAQUE livre visible et relève uniquement ce qui y est IMPRIMÉ.

Pour chaque livre :
- box_2d : le cadre qui entoure ce livre seul (sa tranche ou sa couverture), [ymin, xmin, ymax, xmax] de 0 à 1000.
- title : le titre tel qu'imprimé, sans le compléter ni le corriger. Mets null si tu ne peux pas le lire avec certitude — ne devine jamais un titre.
- authors : le ou les auteurs imprimés, hors traducteur, préfacier et illustrateur. Liste vide si aucun n'est lisible.
- format : 'manga', 'bande-dessinee', 'comic', 'audiobook', 'ebook' ou 'book', selon les mêmes indices que pour une couverture ; null si tu hésites.
- publisher : l'éditeur si son nom ou son logo est lisible, sinon null.
- language : la langue de CETTE édition d'après les textes imprimés, null si rien ne permet de trancher.
- seriesName et volumeNumber : seulement si la tranche ou la couverture les imprime (« Tome 3 », un numéro en bas de tranche). seriesName est le nom de la série seul, sans le numéro. Sinon null.

Un livre partiellement caché compte s'il est identifiable. Un objet qui n'est pas un livre (serre-livres, bibelot, boîte) ne compte pas. Ne répète pas un livre.

N'INVENTE RIEN. Les titres et les auteurs sont recopiés tels qu'imprimés ; toute autre valeur textuelle est en ${LANGUAGE_NAMES[language]}.`
