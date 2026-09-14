import { ChangelogQuery } from '~/domain/changelog/query'
import { builder } from '~/domain/shared/graphql/builder'
import { languageFrom } from '~/domain/shared/language'
import { ChangelogEntryType } from './types'

builder.queryField('changelog', (t) =>
  t.field({
    type: [ChangelogEntryType],
    description:
      'Application release notes, one entry per version, most recent first.\n\n' +
      "Served from the published changelog asset in the caller's language (from `Accept-Language`, " +
      'English fallback). Global (not user-scoped); the app uses it to show what changed in each ' +
      'release.',
    resolve: (_root, _args, { event }) =>
      ChangelogQuery.list(languageFrom(event && getHeader(event, 'accept-language'))),
  }),
)
