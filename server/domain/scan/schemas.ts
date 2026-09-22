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
      description: "ISBN-13 d'une édition courante ; null plutôt qu'un ISBN incertain",
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
            description: 'Année de parution, y compris future pour un volume annoncé',
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
