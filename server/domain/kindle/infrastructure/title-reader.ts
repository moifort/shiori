import { generate } from '~/domain/scan/gemini'

/** One title as the model is asked to split it. */
export type TitleToRead = { asin: string; title: string; author?: string }

/** The model's answer for one title, unchecked. */
export type TitleRead = {
  asin?: string
  title?: string
  seriesName?: string | null
  volumeNumber?: number | null
}

/** How many titles one call reads. Forty fit the answer comfortably and a
 *  165-title library takes five calls side by side. */
export const TITLES_PER_CALL = 40

const SCHEMA = {
  type: 'object',
  properties: {
    books: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          asin: { type: 'string' },
          title: { type: 'string' },
          seriesName: { type: 'string', nullable: true },
          volumeNumber: { type: 'number', nullable: true },
        },
        required: ['asin', 'title', 'seriesName', 'volumeNumber'],
        propertyOrdering: ['asin', 'title', 'seriesName', 'volumeNumber'],
      },
    },
  },
  required: ['books'],
}

/** Amazon's titles are whatever each publisher typed into the catalogue: the
 *  saga, the volume, the edition, the translation, the imprint, all in one
 *  string and in no fixed order. No pattern list keeps up; the model reads
 *  them the way a reader would. Not grounded: the titles carry what is needed,
 *  and the model knows which saga a famous title belongs to. */
const promptFor = (titles: readonly TitleToRead[]) =>
  `Voici des titres de livres numériques tels qu'Amazon les liste dans une bibliothèque Kindle. Chaque éditeur les écrit à sa façon et y mêle le nom de la série, le numéro du tome, la mention de l'édition ou de la traduction, la collection de l'éditeur.

Pour chaque livre, renvoie :
- title : le titre du livre SEUL, tel qu'on l'imprime sur sa couverture, dans la langue du titre fourni. Sans nom de série, sans numéro de tome, sans mention d'édition (« French Edition », « Version française », « Nouvelle traduction »), sans collection d'éditeur, sans nom d'auteur. Garde ce qui distingue deux livres d'un même tome (« première partie », « Partie 2 »). Quand le tome n'a pas de titre propre, le titre est le nom de la série. Ne traduis pas.
- seriesName : le nom de la série ou du cycle romanesque auquel ce livre appartient, dans la langue du titre fourni, sans numéro. Une collection d'éditeur (« Masque Christie », « Folio Junior », « Pocket ») n'est PAS une série. Un titre peut appartenir à une série sans la mentionner. null si le livre est indépendant.
- volumeNumber : le numéro du tome TEL QU'IL FIGURE dans le titre fourni, ou null s'il n'y figure pas. Ne le déduis jamais.

Renvoie exactement un objet par livre, avec son asin.

${JSON.stringify(titles)}`

/** One call for up to `TITLES_PER_CALL` titles. */
export const readTitles = (titles: readonly TitleToRead[]) =>
  generate<{ books?: TitleRead[] }>({
    step: 'kindle-titles',
    parts: [{ text: promptFor(titles) }],
    responseSchema: SCHEMA,
  })
