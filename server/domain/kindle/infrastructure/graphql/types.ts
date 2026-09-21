import type { ImportableKindleBook } from '~/domain/kindle/types'
import { builder } from '~/domain/shared/graphql/builder'

export const KindleBookType = builder.objectRef<ImportableKindleBook>('KindleBook').implement({
  description:
    'One title read off an Amazon data export, before anything is saved.\n\n' +
    'Thin on purpose: the export is a purchase history, not a catalogue. It ' +
    'names the book and who wrote it and carries nothing else — no summary, ' +
    'no cover, no series — so a book catalogued from it is a stub the reader ' +
    'can scan or correct afterwards.',
  fields: (t) => ({
    key: t.exposeString('key', {
      description:
        'What to tick: the title and first author folded together, the way the ' +
        'duplicate check folds them. Pass the ones wanted to `importKindleBooks`.',
    }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    alreadyInLibrary: t.exposeBoolean('alreadyInLibrary', {
      description:
        'Already on the shelf under this title and author, whatever the edition. ' +
        'Show it ticked off and untappable rather than hiding it: hidden, it ' +
        'reads as a title the import lost.',
    }),
  }),
})
