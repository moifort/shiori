import { BOOK_FORMATS, BOOK_LANGUAGES, GENRES } from '~/domain/book/types'
import { VOLUME_KINDS } from '~/domain/series/types'

/** The response schemas handed to Gemini's `responseSchema`, which constrains
 *  decoding rather than merely asking politely for JSON. Every optional field is
 *  `nullable` on purpose: a model that cannot omit a field will invent a value
 *  for it, and an invented ISBN or page count is worse than an absent one.
 *
 *  `propertyOrdering` matters. The decoder emits fields in this order, so the
 *  cheap classifications come first and the expensive prose last — the model has
 *  already committed to what the book IS before it writes about it.
 */

export const VISION_SCHEMA = {
  type: 'object',
  properties: {
    recognized: {
      type: 'boolean',
      description: "false si l'image n'est pas une couverture de livre lisible, true sinon",
    },
    format: {
      type: 'string',
      enum: [...BOOK_FORMATS],
      nullable: true,
      description: 'Nature de l’objet photographié, déduite de la couverture',
    },
    title: { type: 'string', description: 'Titre tel qu’imprimé sur la couverture' },
    authors: {
      type: 'array',
      items: { type: 'string' },
      description: 'Auteurs, hors traducteur, préfacier et illustrateur',
    },
    publisher: { type: 'string', nullable: true, description: 'Éditeur si lisible' },
    language: {
      type: 'string',
      enum: [...BOOK_LANGUAGES],
      nullable: true,
      description: 'Langue dans laquelle cette édition est écrite',
    },
    seriesName: {
      type: 'string',
      nullable: true,
      description: 'Nom de la série seul, sans le numéro de tome',
    },
    volumeNumber: { type: 'integer', nullable: true, description: 'Numéro de tome imprimé' },
  },
  required: ['recognized', 'title', 'authors'],
  propertyOrdering: [
    'recognized',
    'format',
    'title',
    'authors',
    'publisher',
    'language',
    'seriesName',
    'volumeNumber',
  ],
} as const

export const ENRICHMENT_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    authors: { type: 'array', items: { type: 'string' } },
    seriesName: { type: 'string', nullable: true },
    volumeNumber: { type: 'integer', nullable: true },
    volumeKind: { type: 'string', enum: [...VOLUME_KINDS], nullable: true },
    firstPublishedIn: {
      type: 'integer',
      nullable: true,
      description: "Année de première publication de l'œuvre, pas de cette édition",
    },
    genre: {
      type: 'string',
      enum: [...GENRES],
      nullable: true,
      description: 'Un seul genre, le plus précis de la liste ; other si aucun ne convient',
    },
    subgenres: {
      type: 'array',
      items: { type: 'string' },
      description:
        'De 0 à 3 sous-genres libres qui précisent le genre, du plus représentatif au moins représentatif',
    },
    pageCount: { type: 'integer', nullable: true },
    isbn13: {
      type: 'string',
      nullable: true,
      description: "ISBN-13 de cette édition précise ; null plutôt qu'un ISBN incertain",
    },
    regularEditionIsbn13: {
      type: 'string',
      nullable: true,
      description:
        "Si cette édition est spéciale (collector, limitée…), ISBN-13 de l'édition courante ; null sinon",
    },
    synopsis: { type: 'string', nullable: true, description: 'Résumé sans le dénouement' },
  },
  required: ['title', 'authors', 'subgenres'],
  propertyOrdering: [
    'title',
    'authors',
    'seriesName',
    'volumeNumber',
    'volumeKind',
    'firstPublishedIn',
    'genre',
    'subgenres',
    'pageCount',
    'isbn13',
    'regularEditionIsbn13',
    'synopsis',
  ],
} as const

export const CATALOGUE_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    author: { type: 'string' },
    description: { type: 'string', nullable: true },
    volumes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string', enum: [...VOLUME_KINDS] },
          number: {
            type: 'integer',
            nullable: true,
            description: 'Numéro dans la série ; null hors numérotation',
          },
          title: { type: 'string' },
          publishedIn: {
            type: 'integer',
            nullable: true,
            description: "Année de parution dans la langue de l'édition",
          },
        },
        required: ['kind', 'title'],
        // Kind first: classifying the volume before naming it is what keeps a
        // spin-off out of the numbered spine.
        propertyOrdering: ['kind', 'number', 'title', 'publishedIn'],
      },
    },
  },
  required: ['name', 'author', 'volumes'],
  propertyOrdering: ['name', 'author', 'description', 'volumes'],
} as const

/** The books a typed title may mean. Titles and authors only: telling two books
 *  apart takes no synopsis, and a short answer is what keeps the step quick. */
export const CANDIDATES_SCHEMA = {
  type: 'object',
  properties: {
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Titre exact du livre' },
          authors: { type: 'array', items: { type: 'string' } },
          firstPublishedIn: { type: 'integer', nullable: true },
          seriesName: {
            type: 'string',
            nullable: true,
            description: 'Nom de la série seul, sans le numéro de tome',
          },
          volumeNumber: { type: 'integer', nullable: true },
        },
        required: ['title', 'authors'],
        propertyOrdering: ['title', 'authors', 'firstPublishedIn', 'seriesName', 'volumeNumber'],
      },
    },
  },
  required: ['candidates'],
} as const

/** A shelf photo: every book in it, each with its frame. Ungrounded like the
 *  cover's vision step, whose field descriptions it reuses — a spine prints the
 *  same things a cover does, only fewer of them. */
export const SHELF_SCHEMA = {
  type: 'object',
  properties: {
    books: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          box_2d: {
            type: 'array',
            items: { type: 'integer' },
            description: 'Cadre du livre dans la photo : [ymin, xmin, ymax, xmax] de 0 à 1000',
          },
          title: {
            type: 'string',
            nullable: true,
            description: 'Titre tel qu’imprimé, null si illisible',
          },
          authors: VISION_SCHEMA.properties.authors,
          format: VISION_SCHEMA.properties.format,
          publisher: VISION_SCHEMA.properties.publisher,
          language: VISION_SCHEMA.properties.language,
          seriesName: VISION_SCHEMA.properties.seriesName,
          volumeNumber: VISION_SCHEMA.properties.volumeNumber,
        },
        required: ['box_2d', 'authors'],
        propertyOrdering: [
          'box_2d',
          'title',
          'authors',
          'format',
          'publisher',
          'language',
          'seriesName',
          'volumeNumber',
        ],
      },
    },
  },
  required: ['books'],
} as const
