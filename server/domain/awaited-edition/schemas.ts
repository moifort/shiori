export const EDITION_SCHEMA = {
  type: 'object',
  properties: {
    found: { type: 'boolean' },
    title: { type: 'string', nullable: true },
    date: { type: 'string', nullable: true },
    isbn13: { type: 'string', nullable: true },
    asin: { type: 'string', nullable: true },
  },
  required: ['found'],
} as const

export type EditionOutput = {
  found?: boolean
  title?: string | null
  date?: string | null
  isbn13?: string | null
  asin?: string | null
}
