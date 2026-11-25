import { builder } from '~/domain/shared/graphql/builder'

export const PlanEnum = builder.enumType('Plan', {
  description:
    'What an account is entitled to.\n\n' +
    'Everyone starts on `FREE`, and `PREMIUM` is only ever the result of a purchase the App ' +
    'Store signed: an expired, refunded or cancelled-and-elapsed subscription reads back as ' +
    '`FREE`.',
  values: {
    FREE: {
      value: 'free',
      description:
        'An account without a running subscription. The app waits behind the subscription offer, ' +
        'the library kept; no scan or paid lookup is made for it.',
    },
    PREMIUM: {
      value: 'premium',
      description: 'A running subscription, the free trial included: 30 scans a month.',
    },
  } as const,
})
