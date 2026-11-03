import type { Brand } from 'ts-brand'
import type { BookFormat, BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import type { SeriesName, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

/** `{userId}--{shelfKey}`: a reader wishes for a story once. */
export type WishId = Brand<string, 'WishId'>

/** Where the reader came across the book they wish for. */
export type WishOriginKind = 'friend' | 'discovery' | 'award' | 'author' | 'scan'

export type WishOrigin = {
  kind: WishOriginKind
  /** Who or what it came from, as the cover labels it: the friend's first
   *  name, the award's. Kept as it was when wished for. */
  label?: string
  /** The friend it was seen at. */
  friendId?: UserId
}

/** A book the reader does not hold yet and would like to: private, one
 *  document per story, owned by exactly one reader. Not a book — it is never
 *  counted, grouped into a saga or shared — only its catalogue facts as the
 *  page it was wished from showed them. It goes on its own once the library
 *  holds the story. */
export type Wish = {
  id: WishId
  userId: UserId
  title: BookTitle
  authors: AuthorName[]
  format: BookFormat
  language?: BookLanguage
  series?: { name: SeriesName; volume?: VolumeNumber }
  coverUrl?: CoverUrl
  isbn13?: Isbn13
  origin: WishOrigin
  wishedAt: Date
}

/** A book as the reader wishes for it, before it is a wish. */
export type WishedBook = Omit<Wish, 'id' | 'userId' | 'origin' | 'wishedAt'>
