import { builder } from '~/domain/shared/graphql/builder'
import { AvatarColorEnum, AvatarHeroEnum } from './enums'

export const CompleteOnboardingInput = builder.inputType('CompleteOnboardingInput', {
  description:
    'What the onboarding wizard collects.\n\n' +
    'Only a first name, so the app can address the reader. Vinarium also sizes a ' +
    'cellar grid here; a library has no shape to declare up front.',
  fields: (t) => ({
    firstName: t.field({
      type: 'PersonName',
      required: true,
      description: "The reader's first name.",
    }),
  }),
})

export const ChangeAvatarInput = builder.inputType('ChangeAvatarInput', {
  description:
    'What stands for the reader beside their name.\n\n' +
    'A hero, a photo, or a colour for the initials — never two of them. None takes ' +
    'the avatar off, and the app draws the initials on slate.',
  fields: (t) => ({
    hero: t.field({
      type: AvatarHeroEnum,
      required: false,
      description: 'A hero of a classic novel, from the portraits the app bundles.',
    }),
    color: t.field({
      type: AvatarColorEnum,
      required: false,
      description: 'The colour the initials of the first name are drawn on.',
    }),
    photoBase64: t.string({
      required: false,
      description:
        'A photo of the reader, as a base64-encoded JPEG (no data URL prefix), up to ' +
        '2 MB once decoded. The app sends a 512-point square.',
    }),
  }),
})
