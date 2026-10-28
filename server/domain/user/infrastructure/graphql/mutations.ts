import { match, P } from 'ts-pattern'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, notFound } from '~/domain/shared/graphql/errors'
import { UserQuery } from '~/domain/user/query'
import { UserUseCase } from '~/domain/user/use-case'
import { ChangeAvatarInput, CompleteOnboardingInput } from './inputs'
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

builder.mutationField('changeAvatar', (t) =>
  t.field({
    type: MeType,
    description:
      'Change the avatar: a hero, a photo of the reader, a colour for their ' +
      'initials, or none of them for their initials on slate.\n\n' +
      'Returns the updated `Me`. Needs a finished onboarding (`NOT_FOUND` before ' +
      'it); `BAD_USER_INPUT` when more than one of hero, photo and colour is given, or when the ' +
      'photo is not a JPEG under 2 MB. A replaced photo is deleted from storage.',
    args: {
      input: t.arg({ type: ChangeAvatarInput, required: true, description: 'The new avatar.' }),
    },
    resolve: async (_root, { input }, { userId }) => {
      const photo = input.photoBase64 ? Buffer.from(input.photoBase64, 'base64') : undefined
      const outcome = await UserUseCase.changeAvatar(userId, {
        hero: input.hero ?? undefined,
        color: input.color ?? undefined,
        photo,
      })
      return match(outcome)
        .with('no-profile', () => notFound('No profile: finish onboarding first'))
        .with('ambiguous', () => badUserInput('Give a hero, a photo or a colour, only one'))
        .with('invalid-photo', () => badUserInput('The photo must be a JPEG under 2 MB'))
        .with(P.not(P.string), () => UserQuery.me(userId))
        .exhaustive()
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
