import { NotificationSettingsType } from '~/domain/notification/infrastructure/graphql/types'
import { NotificationQuery } from '~/domain/notification/query'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryField('notificationSettings', (t) =>
  t.field({
    type: NotificationSettingsType,
    description: 'The alerts the reader switched on, for the settings screen.',
    resolve: (_root, _args, context) => NotificationQuery.settings(context.userId),
  }),
)
