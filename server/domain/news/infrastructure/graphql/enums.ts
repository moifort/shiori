import { builder } from '~/domain/shared/graphql/builder'

export const FeedEventKindEnum = builder.enumType('FeedEventKind', {
  description: 'What a friend did to a book that the news feed tells.',
  values: {
    STARTED: { value: 'started', description: 'Picked it up.' },
    FINISHED: { value: 'finished', description: 'Finished it; `rating` holds their stars.' },
    LOVED: { value: 'loved', description: 'Hearted it: five stars, always.' },
  } as const,
})

export const ReleaseSourceEnum = builder.enumType('ReleaseSource', {
  description: 'Which of the reader’s follows an upcoming release comes from.',
  values: {
    SAGA: { value: 'saga', description: 'The next volume of a saga they follow.' },
    AUTHOR: { value: 'author', description: 'A new work of an author they hold.' },
    AWAITED: { value: 'awaited', description: 'An edition they await.' },
    NARRATOR: { value: 'narrator', description: 'A recording of a narrator they follow.' },
  } as const,
})
