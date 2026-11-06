import { builder } from '~/domain/shared/graphql/builder'

export const AlertKindEnum = builder.enumType('AlertKind', {
  description:
    'An alert the reader can switch off; every one starts on. Each says ' +
    'something new for the reader: a book coming out, or the month’s discoveries made.',
  values: {
    TRANSLATION: {
      value: 'translation',
      description: 'A new volume of a saga the reader follows, the day it comes out.',
    },
    DIGEST: {
      value: 'digest',
      description:
        'The Sunday digest of the volumes newly announced in the sagas the reader follows.',
    },
    DISCOVERIES: {
      value: 'discoveries',
      description: 'The month’s discoveries, made on the first for a reader who had some before.',
    },
  } as const,
})

export const PushEnvironmentEnum = builder.enumType('PushEnvironment', {
  description:
    'Where a device is reached: an APNs gateway for an iPhone — a development build gets a ' +
    'sandbox token, which the production gateway rejects — or Firebase Cloud Messaging for an ' +
    'Android phone.',
  values: {
    SANDBOX: { value: 'sandbox' },
    PRODUCTION: { value: 'production' },
    FCM: {
      value: 'fcm',
      description: 'An Android phone, reached through Firebase Cloud Messaging.',
    },
  } as const,
})
