import { builder } from '~/domain/shared/graphql/builder'

export const ReadingStatusEnum = builder.enumType('ReadingStatus', {
  description:
    'Where a book stands for its reader.\n\n' +
    '`TO_READ` is where every book lands when catalogued, `READING` is where it ' +
    'spends most of its life, `READ` is the end. Moving between them stamps the ' +
    'reading dates: those follow from the move and are never typed by the reader.',
  values: {
    TO_READ: { value: 'to-read', description: 'On the pile. Clears any reading date it had.' },
    READING: {
      value: 'reading',
      description: 'Started. Stamps `startedAt` the first time, and clears `finishedAt`.',
    },
    READ: {
      value: 'read',
      description: 'Finished. Stamps `finishedAt`, and `startedAt` too if it was never set.',
    },
  } as const,
})

export const BookFormatEnum = builder.enumType('BookFormat', {
  description:
    'What kind of object the reader holds.\n\n' +
    'Prose, sound, or a drawn story. Drawn stories are split into the three ' +
    'traditions readers shelve apart. Defaults to `BOOK` when nothing says otherwise.',
  values: {
    BOOK: { value: 'book', description: 'A printed book: novel, essay, anything in prose.' },
    EBOOK: { value: 'ebook', description: 'A book read on a screen.' },
    AUDIOBOOK: { value: 'audiobook', description: 'A book listened to.' },
    BANDE_DESSINEE: {
      value: 'bande-dessinee',
      description: 'A Franco-Belgian comic album, such as Astérix or Blacksad.',
    },
    COMIC: { value: 'comic', description: 'An American comic book or graphic novel.' },
    MANGA: { value: 'manga', description: 'A Japanese comic, or one drawn in that tradition.' },
  } as const,
})
