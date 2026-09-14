import { builder } from '~/domain/shared/graphql/builder'

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
