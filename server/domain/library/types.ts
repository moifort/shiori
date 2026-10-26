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
