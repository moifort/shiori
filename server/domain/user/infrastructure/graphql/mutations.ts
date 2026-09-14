import { builder } from '~/domain/shared/graphql/builder'
import { UserQuery } from '~/domain/user/query'
import { UserUseCase } from '~/domain/user/use-case'
import { CompleteOnboardingInput } from './inputs'
import { MeType } from './types'

builder.mutationField('completeOnboarding', (t) =>
  t.field({
    type: MeType,
    description:
      'Finish onboarding: save the profile and grant the welcome scans.\n\n' +
      'Returns the updated `Me`, with `onboardingCompleted` now true. The welcome ' +
      'scans are granted only on the first call for an account: the mutation stays ' +
      'reachable afterwards so a reader can change the name they are addressed by, ' +
      'and re-granting there would make a one-off gift renewable.',
    args: {
      input: t.arg({
        type: CompleteOnboardingInput,
        required: true,
        description: 'The first name to persist.',
      }),
    },
    resolve: async (_root, { input }, { userId }) => {
      await UserUseCase.completeOnboarding(userId, { firstName: input.firstName })
      return UserQuery.me(userId)
    },
  }),
)

builder.mutationField('deleteAccount', (t) =>
  t.boolean({
    description:
      'Permanently delete the signed-in account and all of its data.\n\n' +
      'Irreversible. Erases the library, the cover images, the scan allowance and ' +
      'the stored entitlement, drops the profile, and deletes the Firebase Auth ' +
      'user. Does NOT cancel an active App Store subscription: Apple owns that ' +
      'lifecycle, so a subscriber must cancel separately in the App Store. The ' +
      'shared series catalogue is untouched — it belongs to no one and serves ' +
      'every other reader. Always returns `true`.',
    resolve: async (_root, _args, { userId }) => {
      await UserUseCase.deleteAccount(userId)
      return true
    },
  }),
)
