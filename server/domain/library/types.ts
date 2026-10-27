import type { AwardMention } from '~/domain/award/types'
import type { Book, BookFormat, Genre, Subgenre } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'

/** What the Library tab's entry screen is narrowed to: a format pill, and the
 *  genre and subgenre of a genre page. Nothing narrows the whole library. */
export type ShelvesView = { format?: BookFormat; genre?: Genre; subgenre?: Subgenre }

/** The entry screen asked for: the reader and the view, each rail computed
 *  from the one library scan the request shares when its field is selected. */
export type LibraryShelves = { userId: UserId; view: ShelvesView }

/** A genre of the reader's library, as its tile draws it: how many books, and
 *  the cover of the one shelved last that has one. */
export type GenreShelf = { genre: Genre; count: number; cover?: Book }

/** Why the pile offers a book, one section each, in the order the screen
 *  draws them: what the reader began before anything new, then what follows
 *  on from their reading, then what others or the record suggest. */
export const PILE_SECTIONS = [
  'to-finish',
  'next-volume',
  'recommended',
  'favorite-authors',
  'favorite-narrators',
  'awarded',
  'new-authors',
] as const
export type PileSectionKind = (typeof PILE_SECTIONS)[number]

/** A book a section offers, and the prize it won when the section is the
 *  award winners'. */
export type PilePick<T extends Book = Book> = { book: T; award?: AwardMention }

/** One section of the pile: never empty, a few screens' width at most. */
export type PileSection<T extends Book = Book> = { kind: PileSectionKind; picks: PilePick<T>[] }

/** The pile asked for: the reader and the view it is narrowed to. */
export type PileRequest = { userId: UserId; view: ShelvesView }
