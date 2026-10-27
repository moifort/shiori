export const NARRATOR_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    nationality: { type: 'string', nullable: true },
    birthYear: { type: 'integer', nullable: true },
    deathYear: { type: 'integer', nullable: true },
    biography: { type: 'string', nullable: true },
    wikipediaTitle: { type: 'string', nullable: true },
  },
  required: ['name'],
  propertyOrdering: [
    'name',
    'nationality',
    'birthYear',
    'deathYear',
    'biography',
    'wikipediaTitle',
  ],
} as const

export type NarratorOutput = {
  name: string
  nationality?: string | null
  birthYear?: number | null
  deathYear?: number | null
  biography?: string | null
  wikipediaTitle?: string | null
}
