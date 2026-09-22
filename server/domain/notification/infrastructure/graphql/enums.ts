import { builder } from '~/domain/shared/graphql/builder'

export const AlertKindEnum = builder.enumType('AlertKind', {
  description:
    'An alert the reader can switch on. Every one is about a book coming out: ' +
    'Shiori never pushes to bring a reader back.',
  values: {
    SERIES_VOLUME: { value: 'series-volume', description: 'A new volume of a followed saga.' },
    TRANSLATION: {
      value: 'translation',
      description: 'The French translation of a book the reader read in English.',
    },
    AUDIBLE_RELEASE: {
      value: 'audible-release',
      description: 'A new Audible recording in a followed saga.',
    },
    AUTHOR_RELEASE: {
      value: 'author-release',
      description: 'A new book by an author the reader hearted or rated five stars.',
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
