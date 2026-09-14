import { builder } from '~/domain/shared/graphql/builder'

export const ReadingStatusEnum = builder.enumType('ReadingStatus', {
  description:
    'Where a book stands for its reader.\n\n' +
    '`TO_READ` is where every book lands when catalogued, `READING` is where it ' +
    'spends most of its life, `READ` is the end. Moving between them stamps the ' +
    'reading dates: those follow from the move and are never typed by the reader.',
  values: {
    TO_READ: { value: 'to-read', description: 'On the pile. Clears any reading date it had.' },
    READING: {
      value: 'reading',
      description: 'Started. Stamps `startedAt` the first time, and clears `finishedAt`.',
    },
    READ: {
      value: 'read',
      description: 'Finished. Stamps `finishedAt`, and `startedAt` too if it was never set.',
    },
  } as const,
})
