export const AUTHOR_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    nationality: { type: 'string', nullable: true },
    birthYear: { type: 'integer', nullable: true },
    deathYear: { type: 'integer', nullable: true },
    biography: { type: 'string', nullable: true },
    wikipediaTitle: { type: 'string', nullable: true },
    series: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          volumeCount: { type: 'integer', nullable: true },
          firstVolumeTitle: { type: 'string', nullable: true },
        },
        required: ['name'],
        propertyOrdering: ['name', 'volumeCount', 'firstVolumeTitle'],
      },
    },
    books: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          publishedIn: { type: 'integer', nullable: true },
        },
        required: ['title'],
        propertyOrdering: ['title', 'publishedIn'],
      },
    },
  },
  required: ['name', 'series', 'books'],
  propertyOrdering: [
    'name',
    'nationality',
    'birthYear',
    'deathYear',
    'biography',
    'wikipediaTitle',
    'series',
    'books',
  ],
} as const

export type AuthorOutput = {
  name: string
  nationality?: string | null
  birthYear?: number | null
  deathYear?: number | null
  biography?: string | null
  wikipediaTitle?: string | null
  series: { name: string; volumeCount?: number | null; firstVolumeTitle?: string | null }[]
  books: { title: string; publishedIn?: number | null }[]
}
