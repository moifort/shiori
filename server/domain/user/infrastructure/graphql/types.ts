import { builder } from '~/domain/shared/graphql/builder'
import {
  AvatarColorEnum,
  AvatarHeroEnum,
  HomePromptEnum,
} from '~/domain/user/infrastructure/graphql/enums'
import type { MeView } from '~/domain/user/types'
import { UserUseCase } from '~/domain/user/use-case'
import { objectStore } from '~/system/object-store'

export const MeType = builder.objectRef<MeView>('Me').implement({
  description:
    'The signed-in user: their identity and onboarding state.\n\n' +
    'Always resolvable from the auth token, so `userId` is always present. Every other field is null until the onboarding wizard completes, which lets the app route a fresh account into onboarding.\n\n' +
    '```graphql\n' +
    'query {\n' +
    '  me {\n' +
    '    userId\n' +
    '    firstName\n' +
    '    onboardingCompleted\n' +
    '  }\n' +
    '}\n' +
    '```',
  fields: (t) => ({
    userId: t.expose('userId', {
      type: 'UserId',
      description: 'The Firebase Auth user id, also the id of the profile document.',
    }),
    firstName: t.expose('firstName', {
      type: 'PersonName',
      nullable: true,
      description: "The user's first name, set during onboarding; null before it is done.",
    }),
    onboardingCompletedAt: t.expose('onboardingCompletedAt', {
      type: 'DateTime',
      nullable: true,
      description: 'When onboarding finished, or null if it never has.',
    }),
    onboardingCompleted: t.boolean({
      description: 'Convenience flag the app routes on: true once onboarding is done.',
      resolve: (me) => me.onboardingCompletedAt != null,
    }),
    avatarHero: t.field({
      type: AvatarHeroEnum,
      nullable: true,
      description:
        'The hero the reader wears as an avatar, drawn by the app from its own ' +
        'portraits. Null with a photo, and with no avatar at all, which the app ' +
        'draws as the initials of `firstName`.',
      resolve: (me) => (me.avatar?.kind === 'hero' ? me.avatar.hero : null),
    }),
    avatarColor: t.field({
      type: AvatarColorEnum,
      nullable: true,
      description:
        'The colour the reader’s initials are drawn on. Null with a hero or a photo, ' +
        'and with no avatar at all, which the app draws on slate.',
      resolve: (me) => (me.avatar?.kind === 'initials' ? me.avatar.color : null),
    }),
    avatarUrl: t.string({
      nullable: true,
      description:
        'The photo the reader chose as an avatar, as a URL signed for one hour. ' +
        'Each new photo has its own URL, so a cached image is never stale. Null ' +
        'with a hero or no avatar.',
      resolve: async (me) =>
        me.avatar?.kind === 'photo' ? objectStore().downloadUrl(me.avatar.path) : null,
    }),
    homePrompts: t.field({
      type: [HomePromptEnum],
      description:
        'What the home screen’s hero asks the reader to set up, in the order it asks: ' +
        'Audible and Kindle until each is connected, a first friend until they have ' +
        'one, less what they turned down with `dismissHomePrompt`. Empty once all is ' +
        'done or declined. Reads both connections and the friendships.',
      resolve: (me) => UserUseCase.homePrompts(me),
    }),
    isAdmin: t.expose('admin', {
      type: 'Boolean',
      description:
        'Whether this account may open the in-app admin screen (`adminMetrics`). ' +
        'Set by hand on the profile document, false for everyone else.',
    }),
  }),
})
