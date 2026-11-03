import { match, P } from 'ts-pattern'
import { coverSourcesOf } from '~/domain/book/business-rules'
import {
  BookFormatEnum,
  BookLanguageEnum,
  heldAs,
} from '~/domain/book/infrastructure/graphql/enums'
import { SeriesPlacementInput } from '~/domain/book/infrastructure/graphql/inputs'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, domainError, notFound } from '~/domain/shared/graphql/errors'
import { UserQuery } from '~/domain/user/query'
import { WishOriginEnum, WishType } from '~/domain/wish/infrastructure/graphql/types'
import { type WishOutcome, WishUseCase } from '~/domain/wish/use-case'

const wishOrError = (outcome: WishOutcome) =>
  match(outcome)
    .with('in-library', () =>
      domainError('ALREADY_IN_LIBRARY', 'That book is already in your library'),
    )
    .with('too-many', () => domainError('TOO_MANY_WISHES', 'Too many books wished for'))
    .with({ id: P.string }, (wish) => wish)
    .exhaustive()

const WISH_DESCRIPTION =
  'Wishing for it twice answers the first wish, from wherever it came. Fails with ' +
  '`ALREADY_IN_LIBRARY` when the library holds the story, and `TOO_MANY_WISHES` past ' +
  'five hundred.'

const WishedBookInput = builder.inputType('WishedBookInput', {
  description: 'A book as the page the reader wishes for it from shows it.',
  fields: (t) => ({
    title: t.field({ type: 'BookTitle', required: true }),
    authors: t.field({ type: ['AuthorName'], required: false }),
    format: t.field({ type: BookFormatEnum, required: true }),
    language: t.field({ type: BookLanguageEnum, required: false }),
    series: t.field({ type: SeriesPlacementInput, required: false }),
    coverUrl: t.field({ type: 'CoverUrl', required: false }),
    isbn13: t.field({ type: 'Isbn13', required: false }),
  }),
})

builder.mutationFields((t) => ({
  wishBook: t.field({
    type: WishType,
    description:
      'Wish for a book seen in Découvrir, among an award’s winners or an author’s works, ' +
      `or scanned and not added. ${WISH_DESCRIPTION} A friend’s book goes through ` +
      '`wishFriendBook`: `BAD_USER_INPUT` for the `FRIEND` origin here.',
    args: {
      book: t.arg({ type: WishedBookInput, required: true }),
      origin: t.arg({ type: WishOriginEnum, required: true }),
      originLabel: t.arg.string({
        required: false,
        description: 'What the cover labels it with: the award’s name, say.',
      }),
    },
    resolve: async (_root, { book, origin, originLabel }, context) => {
      if (origin === 'friend') return badUserInput('Wish for a friend’s book with wishFriendBook')
      return wishOrError(
        await WishUseCase.wish(
          context.userId,
          {
            title: book.title,
            authors: book.authors ?? [],
            format: heldAs(book.format).format ?? 'book',
            ...(book.language ? { language: book.language } : {}),
            ...(book.series
              ? {
                  series: {
                    name: book.series.name,
                    ...(book.series.volume != null ? { volume: book.series.volume } : {}),
                  },
                }
              : {}),
            ...(book.coverUrl ? { coverUrl: book.coverUrl } : {}),
            ...(book.isbn13 ? { isbn13: book.isbn13 } : {}),
          },
          { kind: origin, ...(originLabel ? { label: originLabel.slice(0, 80) } : {}) },
        ),
      )
    },
  }),

  wishFriendBook: t.field({
    type: WishType,
    description:
      'Wish for a book seen on a friend’s shelf. Only the friend and the book are named: ' +
      'the server re-reads the book and keeps its catalogue facts, never what the friend ' +
      `made of it, nor their photo of the cover. ${WISH_DESCRIPTION} \`NOT_FOUND\` for a ` +
      'stranger, a missing book or one marked "do not share".',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
    },
    resolve: async (_root, args, context) => {
      const [book, names] = await Promise.all([
        FriendshipUseCase.book(context.userId, args.userId, args.bookId),
        UserQuery.namesOf([args.userId]),
      ])
      if (!book) return notFound('Book not found')
      const cover = coverSourcesOf(book).publishedCoverUrl
      const name = names.get(args.userId)
      return wishOrError(
        await WishUseCase.wish(
          context.userId,
          {
            title: book.title,
            authors: book.authors,
            format: book.format,
            ...(book.language ? { language: book.language } : {}),
            ...(book.series
              ? {
                  series: {
                    name: book.series.name,
                    ...(book.series.volume !== undefined ? { volume: book.series.volume } : {}),
                  },
                }
              : {}),
            ...(cover ? { coverUrl: cover } : {}),
            ...(book.isbn13 ? { isbn13: book.isbn13 } : {}),
          },
          { kind: 'friend', friendId: args.userId, ...(name ? { label: name } : {}) },
        ),
      )
    },
  }),

  removeWish: t.boolean({
    description: 'Drop a wish. False when the reader has none by that id.',
    args: { id: t.arg({ type: 'WishId', required: true }) },
    resolve: (_root, { id }, context) => WishUseCase.remove(context.userId, id),
  }),
}))
