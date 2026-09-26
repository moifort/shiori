import { builder } from '~/domain/shared/graphql/builder'

export const AlertKindEnum = builder.enumType('AlertKind', {
  description:
    'An alert the reader can switch off; every one starts on. Every one is ' +
    'about a book coming out: Shiori never pushes to bring a reader back.',
  values: {
    TRANSLATION: {
      value: 'translation',
      description: 'A new volume of a saga the reader follows, the day it comes out.',
    },
  } as const,
})

export const PushEnvironmentEnum = builder.enumType('PushEnvironment', {
  description:
    'Which APNs gateway a device token belongs to: a development build gets a ' +
    'sandbox token, which the production gateway rejects.',
  values: {
    SANDBOX: { value: 'sandbox' },
    PRODUCTION: { value: 'production' },
  } as const,
})
