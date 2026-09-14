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
        'The plan every account starts on. The app is fully usable; only the AI scan is metered ' +
        'against a monthly allowance.',
    },
    PREMIUM: {
      value: 'premium',
      description: 'A running subscription. Scanning is unlimited, within a fair-use ceiling.',
    },
  } as const,
})
