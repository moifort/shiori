import { BOOK_LANGUAGES } from '~/domain/book/types'

export const RELEASES_SCHEMA = {
  type: 'object',
  properties: {
    works: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string' },
          translatedTitle: { type: 'string', nullable: true },
          editions: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string' },
                volume: { type: 'integer', nullable: true },
                format: { type: 'string', enum: ['book', 'audiobook'] },
                date: { type: 'string', nullable: true },
                language: { type: 'string', enum: [...BOOK_LANGUAGES], nullable: true },
                isbn13: { type: 'string', nullable: true },
              },
              required: ['title', 'format'],
            },
          },
        },
        required: ['key', 'editions'],
      },
    },
  },
  required: ['works'],
} as const

export type EditionOutput = {
  title?: string
  volume?: number | null
  format?: string
  date?: string | null
  language?: string | null
  isbn13?: string | null
}

export type ReleasesOutput = {
  works?: { key?: string; translatedTitle?: string | null; editions?: EditionOutput[] }[]
}
