import { builder } from '~/domain/shared/graphql/builder'
import { UserQuery } from '~/domain/user/query'
import { MeType } from './types'

builder.queryField('me', (t) =>
  t.field({
    type: MeType,
    description:
      'The signed-in user, resolved from the auth token.\n\n' +
      'Always returns a `Me`, even before onboarding: a fresh account comes back with only `userId` set, which the app uses to route into the onboarding wizard.',
    resolve: (_root, _args, { userId }) => UserQuery.me(userId),
  }),
)
