import { AudibleQuery } from '~/domain/audible/query'
import { storeUrlOf } from '~/domain/awaited-edition/business-rules'
import type { AwaitedEditionView, EditionOffer } from '~/domain/awaited-edition/types'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { objectStore } from '~/system/object-store'

export const AwaitedStateEnum = builder.enumType('AwaitedState', {
  description: 'Where an edition the reader awaits stands.',
  values: {
    UNANNOUNCED: { value: 'unannounced', description: 'The web has found nothing of it yet.' },
    ANNOUNCED: {
      value: 'announced',
      description: 'Found, but not out: announced for a date, or for none yet.',
    },
    AVAILABLE: {
      value: 'available',
      description: 'Out: a printed edition past its date, a recording once Audible confirmed it.',
    },
  } as const,
})

export const AwaitedEditionType = builder
  .objectRef<AwaitedEditionView>('AwaitedEdition')
  .implement({
    description:
      'A book the reader waits to see come out in the language of their app, in one ' +
      'format: translated into print, or recorded. The web is searched for it once a ' +
      'week, and an alert goes out the day it comes out. It stops being awaited on its ' +
      'own once the library holds it — the Audible sync bringing it in, or the reader ' +
      'adding it.',
    fields: (t) => ({
      id: t.field({ type: 'AwaitedEditionId', resolve: (view) => view.id }),
      format: t.field({ type: ReleaseFormatEnum, resolve: (view) => view.format }),
      language: t.field({
        type: BookLanguageEnum,
        description: 'The language it is awaited in: the app’s when the reader asked.',
        resolve: (view) => view.language,
      }),
      state: t.field({ type: AwaitedStateEnum, resolve: (view) => view.state }),
      watched: t.boolean({
        description: 'Whether the web was ever searched for it.',
        resolve: (view) => view.watched,
      }),
      title: t.field({
        type: 'BookTitle',
        description: 'Its title in the language awaited once found, else the original’s.',
        resolve: (view) => view.found?.title ?? view.source.title,
      }),
      originalTitle: t.field({
        type: 'BookTitle',
        description: 'The title of the book it was awaited from.',
        resolve: (view) => view.source.title,
      }),
      originalLanguage: t.field({
        type: BookLanguageEnum,
        resolve: (view) => view.source.language,
      }),
      authors: t.field({ type: ['AuthorName'], resolve: (view) => view.source.authors }),
      date: t.string({
        nullable: true,
        description:
          'When it comes out or came out, as precisely as announced: `YYYY`, `YYYY-MM` ' +
          'or `YYYY-MM-DD`. Null until found, and for an edition announced with no date.',
        resolve: (view) => view.found?.date ?? null,
      }),
      coverUrl: t.string({
        nullable: true,
        description:
          'The edition’s own cover once found, else the cover of the book it was ' +
          'awaited from.',
        resolve: async (view) =>
          view.found?.coverUrl ??
          view.source.coverUrl ??
          (view.source.coverPath ? await objectStore().downloadUrl(view.source.coverPath) : null),
      }),
      storeUrl: t.string({
        nullable: true,
        description:
          'Where to get it: the recording’s page on the reader’s Audible store, which ' +
          'the Audible app opens on the title, or the printed edition’s on Amazon. ' +
          'Null until a store confirmed it.',
        resolve: async (view, _args, { userId }) => {
          const asin = view.format === 'audiobook' ? view.found?.asin : undefined
          const own = asin ? await AudibleQuery.recordingUrlOf(userId, asin) : undefined
          return (
            own ?? (view.found ? storeUrlOf(view.format, view.language, view.found) : null) ?? null
          )
        },
      }),
      awaitedAt: t.field({
        type: 'DateTime',
        description: 'When the reader started awaiting it.',
        resolve: (view) => view.awaitedAt,
      }),
      bookId: t.field({
        type: 'BookId',
        description: 'The book it was awaited from, on its owner’s shelf.',
        resolve: (view) => view.source.bookId,
      }),
      ownerId: t.field({
        type: 'UserId',
        description: 'Whose shelf that book is on: the reader’s, or a friend’s.',
        resolve: (view) => view.source.ownerId,
      }),
    }),
  })

export const EditionOfferType = builder.objectRef<EditionOffer>('EditionOffer').implement({
  description:
    'What a book’s page offers to await: its edition in the language of the app, in ' +
    'each format it may be awaited in, and the ones the reader awaits already.',
  fields: (t) => ({
    formats: t.field({
      type: [ReleaseFormatEnum],
      description:
        'The formats it may be awaited in. None for a book already in the app’s ' +
        'language; a recording only for a reader whose library holds one — and, for a ' +
        'printed book in the app’s language, only once Audible is known not to sell it.',
      resolve: (offer) => offer.formats,
    }),
    awaited: t.field({
      type: [AwaitedEditionType],
      description: 'The editions of this book the reader awaits already.',
      resolve: (offer) => offer.awaited,
    }),
  }),
})
