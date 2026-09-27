export const RELEASES_SCHEMA = {
  type: 'object',
  properties: {
    volumes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          number: { type: 'integer' },
          title: { type: 'string' },
          date: { type: 'string', nullable: true },
          isbn13: { type: 'string', nullable: true },
          asin: { type: 'string', nullable: true },
        },
        required: ['number', 'title'],
      },
    },
  },
  required: ['volumes'],
} as const

export type VolumeOutput = {
  number?: number | null
  title?: string
  date?: string | null
  isbn13?: string | null
  asin?: string | null
}

export type ReleasesOutput = { volumes?: VolumeOutput[] }

export const AUTHOR_RELEASES_SCHEMA = {
  type: 'object',
  properties: {
    works: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          date: { type: 'string', nullable: true },
          isbn13: { type: 'string', nullable: true },
          asin: { type: 'string', nullable: true },
          series: { type: 'string', nullable: true },
          volume: { type: 'integer', nullable: true },
        },
        required: ['title'],
      },
    },
  },
  required: ['works'],
} as const

export type WorkOutput = {
  title?: string
  date?: string | null
  isbn13?: string | null
  asin?: string | null
  series?: string | null
  volume?: number | null
}

export type AuthorReleasesOutput = { works?: WorkOutput[] }
