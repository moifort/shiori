import { BOOK_LANGUAGES, GENRES } from '~/domain/book/types'

const ITEM = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    authors: { type: 'array', items: { type: 'string' } },
    year: { type: 'integer', nullable: true },
    isbn13: { type: 'string', nullable: true },
    seriesName: { type: 'string', nullable: true },
    volume: { type: 'integer', nullable: true },
    genre: { type: 'string', enum: [...GENRES], nullable: true },
    language: { type: 'string', enum: [...BOOK_LANGUAGES], nullable: true },
    synopsis: { type: 'string', nullable: true },
    publicRating: { type: 'number', nullable: true },
    ratingCount: { type: 'integer', nullable: true },
    award: { type: 'string', nullable: true },
    reason: { type: 'string' },
  },
  required: ['title', 'authors', 'reason'],
} as const

export type SuggestionOutput = {
  title?: string
  authors?: string[]
  year?: number | null
  isbn13?: string | null
  seriesName?: string | null
  volume?: number | null
  genre?: string | null
  language?: string | null
  synopsis?: string | null
  publicRating?: number | null
  ratingCount?: number | null
  award?: string | null
  reason?: string
}

export const PERSONAL_SCHEMA = {
  type: 'object',
  properties: {
    becauseYouLoved: {
      type: 'array',
      items: {
        type: 'object',
        properties: { anchor: { type: 'string' }, items: { type: 'array', items: ITEM } },
        required: ['anchor', 'items'],
      },
    },
    offTrail: { type: 'array', items: ITEM },
  },
  required: ['becauseYouLoved', 'offTrail'],
} as const

export type PersonalOutput = {
  becauseYouLoved?: { anchor?: string; items?: SuggestionOutput[] }[]
  offTrail?: SuggestionOutput[]
}

export const GENRE_LIST_SCHEMA = {
  type: 'object',
  properties: {
    awards: { type: 'array', items: ITEM },
    acclaimed: { type: 'array', items: ITEM },
  },
  required: ['awards', 'acclaimed'],
} as const

export type GenreListOutput = { awards?: SuggestionOutput[]; acclaimed?: SuggestionOutput[] }

export const RELEASES_SCHEMA = {
  type: 'object',
  properties: {
    subjects: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string' },
          releases: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string' },
                authors: { type: 'array', items: { type: 'string' } },
                volume: { type: 'integer', nullable: true },
                date: { type: 'string' },
                format: { type: 'string', enum: ['book', 'audiobook'] },
                language: { type: 'string', enum: [...BOOK_LANGUAGES], nullable: true },
                isbn13: { type: 'string', nullable: true },
              },
              required: ['title', 'authors', 'date', 'format'],
            },
          },
        },
        required: ['key', 'releases'],
      },
    },
  },
  required: ['subjects'],
} as const

export type ReleasesOutput = {
  subjects?: {
    key?: string
    releases?: {
      title?: string
      authors?: string[]
      volume?: number | null
      date?: string
      format?: string
      language?: string | null
      isbn13?: string | null
    }[]
  }[]
}
