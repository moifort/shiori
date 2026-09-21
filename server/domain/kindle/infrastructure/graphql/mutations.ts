import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { KindleBookType } from '~/domain/kindle/infrastructure/graphql/types'
import { KindleUseCase } from '~/domain/kindle/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput } from '~/domain/shared/graphql/errors'

/** Amazon's export of a big library runs to a few hundred rows of title and
 *  author. A megabyte is far past that and stops a paste of something else
 *  entirely from being parsed as a spreadsheet. */
const MAX_EXPORT_BYTES = 1_000_000

const UNREADABLE =
  'This file carries no column that could hold a title. Amazon ships several ' +
  'CSVs in one archive: the one to send is the list of digital content owned, ' +
  'not an order history or a reading session.'

builder.mutationFields((t) => ({
  readKindleExport: t.field({
    type: [KindleBookType],
    description:
      'Read an Amazon data export and answer with the books it holds, ticked ' +
      'against the library they would join.\n\n' +
      'Nothing is saved: the answer is a proposal, as a scan is. The app lists ' +
      'the titles, the reader ticks, and `importKindleBooks` catalogues those.\n\n' +
      'No model is called and no scan is spent — this reads a file. Fails with ' +
      '`BAD_USER_INPUT` for a file above one megabyte or one with no title ' +
      'column, which is what the wrong CSV out of the archive looks like.',
    args: {
      csv: t.arg.string({ required: true, description: 'The export file, as text' }),
    },
    resolve: async (_root, { csv }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 1 MB limit')
      const found = await KindleUseCase.read(userId, csv)
      return found === 'no-title-column' ? badUserInput(UNREADABLE) : found
    },
  }),

  importKindleBooks: t.field({
    type: [BookType],
    description:
      'Catalogue the titles the reader ticked, from the keys `readKindleExport` ' +
      'answered with.\n\n' +
      'The file is sent again rather than the records: it is read a second time ' +
      'and the keys only say which of its rows were wanted, so every stored ' +
      'field comes from the export. A title already on the shelf is skipped ' +
      'however it was ticked.\n\n' +
      'Each book lands on the pile as an ebook with its title and author and ' +
      'nothing else: that is all the export carries. Answers the books actually ' +
      'catalogued, which is empty when every ticked title was already owned.',
    args: {
      csv: t.arg.string({ required: true, description: 'The same export file, as text' }),
      keys: t.arg.stringList({ required: true, description: 'The keys of the ticked books' }),
    },
    resolve: async (_root, { csv, keys }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 1 MB limit')
      const imported = await KindleUseCase.importBooks(userId, csv, keys)
      return imported === 'no-title-column' ? badUserInput(UNREADABLE) : imported
    },
  }),
}))
