import { shelfKeyOf } from '~/domain/book/business-rules'
import type { BookLanguage } from '~/domain/book/types'
import { releaseFormatOf } from '~/domain/discovery/business-rules'
import { releaseKeyOf } from '~/domain/release/business-rules'
import type { ReleaseIdentity, ReleaseShown } from '~/domain/release/types'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { WishId } from '~/domain/wish/primitives'
import type { Wish, WishedBook } from '~/domain/wish/types'

/** A reader wishes for as many books as they like, within reason. */
export const MAX_WISHES = 500

/** One wish per story: the same novel wished from a friend and from Découvrir
 *  is one wish, whatever the format. */
export const wishIdOf = (userId: UserId, book: Pick<WishedBook, 'title' | 'authors'>) =>
  WishId(`${userId}--${shelfKeyOf(book.title, book.authors[0])}`)

/** Whether the library holds the story wished for. */
export const isHeld = (wish: Pick<Wish, 'title' | 'authors'>, shelfKeys: ReadonlySet<string>) =>
  shelfKeys.has(shelfKeyOf(wish.title, wish.authors[0]))

/** The wishes as the list draws them: the latest wished first. */
export const newestFirst = (wishes: readonly Wish[]): Wish[] =>
  [...wishes].sort((a, b) => b.wishedAt.getTime() - a.wishedAt.getTime())

/** The edition a wish is described in: the one it was wished in, else the
 *  app's. */
const editionOf = (wish: Pick<Wish, 'language'>, appLanguage: Language): BookLanguage =>
  wish.language ?? appLanguage

/** The book a wish's release is of: the story wished for, in its format and
 *  edition, so the page converges on the same shared description as a list
 *  showing that edition. */
export const releaseIdentityOf = (wish: Wish, appLanguage: Language): ReleaseIdentity => {
  const format = releaseFormatOf(wish.format)
  const language = editionOf(wish, appLanguage)
  return {
    key: releaseKeyOf(wish.title, wish.authors[0], format, language),
    title: wish.title,
    ...(wish.authors[0] ? { author: wish.authors[0] } : {}),
    originalLanguage: language,
    ...(wish.series ? { series: wish.series } : {}),
    format,
    language,
  }
}

/** A wish as its page shows it before its description: what the page it was
 *  wished from showed. It is out, being something to have now, and found as
 *  it was wished — what its store link is made of: the printed edition's
 *  page when its ISBN is known, a search on its title and author otherwise. */
export const releaseShownOf = (wish: Wish, appLanguage: Language): ReleaseShown => {
  const identity = releaseIdentityOf(wish, appLanguage)
  return {
    key: identity.key,
    seed: {
      title: wish.title,
      authors: wish.authors,
      format: wish.format,
      ...(wish.language ? { language: wish.language } : {}),
      ...(wish.isbn13 ? { isbn13: wish.isbn13 } : {}),
      ...(wish.coverUrl ? { coverUrl: wish.coverUrl } : {}),
    },
    originalTitle: wish.title,
    originalLanguage: identity.language,
    language: identity.language,
    releaseFormat: identity.format,
    state: 'available',
    watched: false,
    found: {
      title: wish.title,
      ...(wish.isbn13 && identity.format === 'book' ? { isbn13: wish.isbn13 } : {}),
    },
    ...(wish.coverUrl ? { fallbackCoverUrl: wish.coverUrl } : {}),
    ...(wish.series ? { series: wish.series } : {}),
  }
}
