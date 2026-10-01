import { builder } from '~/domain/shared/graphql/builder'

export const CopiedStatusEnum = builder.enumType('CopiedStatus', {
  description: "Where a book copied from a friend's shelf lands on the reader's own.",
  values: {
    TO_READ: { value: 'to-read', description: 'On the pile.' },
    READ: { value: 'read', description: 'Among the books read: the reader had already read it.' },
  } as const,
})

export const FriendActivityKindEnum = builder.enumType('FriendActivityKind', {
  description: "What happened lately to a book on a friend's shelf.",
  values: {
    READING: {
      value: 'reading',
      description: 'Picked up or read on: the book in progress touched last.',
    },
    READ: { value: 'read', description: 'Finished: the book read last.' },
    HEARTED: { value: 'hearted', description: 'Hearted: the favourite given last.' },
    ADDED: {
      value: 'added',
      description: 'Shelved: the book added last, whatever its status since.',
    },
    DROPPED: { value: 'dropped', description: 'Dropped: the book given up last.' },
  } as const,
})

export const AudioAvailabilityEnum = builder.enumType('AudioAvailability', {
  description: "Whether a friend's book can be taken as an audiobook.",
  values: {
    AVAILABLE: {
      value: 'available',
      description: 'A recording, or a printed book Audible sells in its language.',
    },
    UNAVAILABLE: {
      value: 'unavailable',
      description: 'Audible sells no recording of it in its language.',
    },
    UNKNOWN: {
      value: 'unknown',
      description:
        'Audible could not be asked, or the book records no language: the reader decides.',
    },
  } as const,
})
