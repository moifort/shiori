import type { ChangelogEntry } from '~/domain/changelog/types'
import { builder } from '~/domain/shared/graphql/builder'

export const ChangelogEntryType = builder.objectRef<ChangelogEntry>('ChangelogEntry').implement({
  description:
    'One version section of the application release notes.\n\n' +
    'Parsed from the served changelog document: a version heading, its release date, and the ' +
    'flat list of note lines under it. The app renders it as a row titled by `version` with the ' +
    'formatted `date` on the right and `notes` as bullet points.',
  fields: (t) => ({
    version: t.exposeString('version', {
      description: 'App Store version this section documents (e.g. "1.3")',
    }),
    date: t.expose('date', {
      type: 'DateTime',
      nullable: true,
      description: 'Release date of the version; null for a pending (unreleased) section',
    }),
    notes: t.exposeStringList('notes', {
      description: 'Release note lines for this version, shown as a flat bullet list',
    }),
  }),
})
