import { AdminMetricsType } from '~/domain/admin/infrastructure/graphql/types'
import { AdminQuery } from '~/domain/admin/query'
import { builder } from '~/domain/shared/graphql/builder'
import { forbidden } from '~/domain/shared/graphql/errors'
import { UserQuery } from '~/domain/user/query'

builder.queryField('adminMetrics', (t) =>
  t.field({
    type: AdminMetricsType,
    description:
      "The app's monthly economics: costs, revenue, users and subscribers.\n\n" +
      'Reserved for administrator accounts (see `me.isAdmin`); anyone else is refused with ' +
      '`FORBIDDEN`.',
    resolve: async (_root, _args, { userId }) => {
      const me = await UserQuery.me(userId)
      if (!me.admin) return forbidden('Reserved for administrator accounts')
      return AdminQuery.metrics()
    },
  }),
)
