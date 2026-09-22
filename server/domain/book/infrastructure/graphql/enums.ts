import { builder } from '~/domain/shared/graphql/builder'

export const ReadingStatusEnum = builder.enumType('ReadingStatus', {
  description:
    'Where a book stands for its reader.\n\n' +
    '`TO_READ` is where every book lands when catalogued, `READING` is where it ' +
    'spends most of its life, `READ` is the end, `DROPPED` the end of a book not finished. Moving between them stamps the ' +
    'reading dates, which the reader may then correct through updateBook.',
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
    DROPPED: {
      value: 'dropped',
      description:
        'Stopped for good, the reader did not like it. Keeps `startedAt` (stamping it ' +
        'if it was never set) and clears `finishedAt`: a dropped book was not read.',
    },
  } as const,
})

export const GenreEnum = builder.enumType('Genre', {
  description:
    'What a book is about, from a closed list.\n\n' +
    'Closed so that statistics can count against it; nuance goes to subgenres. ' +
    'Audience (young adult, children) is not a genre, and the object (manga, comic) ' +
    'is the format. `OTHER` when nothing fits.',
  values: {
    FANTASY: { value: 'fantasy' },
    SCIENCE_FICTION: { value: 'science-fiction' },
    HORROR: { value: 'horror' },
    CRIME: { value: 'crime', description: 'Detective and police fiction.' },
    THRILLER: { value: 'thriller' },
    ROMANCE: { value: 'romance' },
    HISTORICAL_FICTION: { value: 'historical-fiction' },
    ADVENTURE: { value: 'adventure' },
    LITERARY_FICTION: { value: 'literary-fiction', description: 'General literature.' },
    HUMOR: { value: 'humor' },
    POETRY: { value: 'poetry' },
    DRAMA: { value: 'drama', description: 'Plays.' },
    BIOGRAPHY: { value: 'biography', description: 'Biographies and memoirs.' },
    HISTORY: { value: 'history', description: 'Non-fiction history.' },
    ESSAY: { value: 'essay' },
    SCIENCE: { value: 'science' },
    SELF_HELP: { value: 'self-help' },
    BUSINESS: { value: 'business', description: 'Economics and business.' },
    ART: { value: 'art' },
    COOKING: { value: 'cooking' },
    TRAVEL: { value: 'travel' },
    OTHER: { value: 'other', description: 'Nothing in the list fits.' },
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

export const BookLanguageEnum = builder.enumType('BookLanguage', {
  description:
    'The language an edition is printed or recorded in — the object on the shelf, ' +
    'never the language the app is being used in.\n\n' +
    'A closed list, for the reason `Genre` is closed and one of its own: the app ' +
    'draws a flag per language, and an arbitrary ISO code has no flag to draw. An ' +
    'edition in a language the list does not carry keeps no language at all, rather ' +
    'than an `OTHER` that would be a second way of saying "unknown".',
  values: {
    FR: { value: 'fr' },
    EN: { value: 'en' },
    ES: { value: 'es' },
    DE: { value: 'de' },
    IT: { value: 'it' },
    PT: { value: 'pt' },
    NL: { value: 'nl' },
    SV: { value: 'sv' },
    PL: { value: 'pl' },
    RU: { value: 'ru' },
    UK: { value: 'uk', description: 'Ukrainian.' },
    TR: { value: 'tr' },
    AR: { value: 'ar' },
    JA: { value: 'ja' },
    ZH: { value: 'zh' },
    KO: { value: 'ko' },
  } as const,
})
