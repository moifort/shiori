import { GoodreadsImportType } from '~/domain/goodreads/infrastructure/graphql/types'
import { GoodreadsUseCase } from '~/domain/goodreads/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  goodreadsImport: t.field({
    type: GoodreadsImportType,
    nullable: true,
    description: "The reader's last Goodreads import, or null when they never imported one.",
    resolve: async (_root, _args, { userId }) =>
      (await GoodreadsUseCase.lastImport(userId)) ?? null,
  }),
}))
