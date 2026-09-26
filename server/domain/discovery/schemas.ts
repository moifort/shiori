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
