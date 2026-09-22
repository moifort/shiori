import { builder } from '~/domain/shared/graphql/builder'

export const CopiedStatusEnum = builder.enumType('CopiedStatus', {
  description: "Where a book copied from a friend's shelf lands on the reader's own.",
  values: {
    TO_READ: { value: 'to-read', description: 'On the pile.' },
    READ: { value: 'read', description: 'Among the books read: the reader had already read it.' },
  } as const,
})
