import type { Brand } from 'ts-brand'
import type { PortraitUrl } from '~/domain/author/types'
import type { NarratorName } from '~/domain/book/types'
import type { SagaKey } from '~/domain/series/types'
import type { Count, UserId } from '~/domain/shared/types'

/** A narrator as the reader's recordings name them, folded as an author is —
 *  diacritics dropped, punctuation collapsed — so "Frédéric Kneip" and
 *  "Frederic Kneip" meet. Derived, never typed. */
export type NarratorKey = Brand<string, 'NarratorKey'>

/** A narrator the reader holds at least one recording of. Derived per request
 *  from the books and the saga opinions, never stored, as an author is.
 *
 *  Generic over the book so the caller keeps whatever it passed in. */
export type ShelvedNarrator<Book> = {
  key: NarratorKey
  /** The spelling most of the reader's recordings use, the newest breaking a tie. */
  name: NarratorName
  /** Every recording of theirs the reader holds, newest shelved first. A
   *  recording read by two is on both. */
  books: Book[]
  /** The sagas heard those recordings belong to, each once. */
  seriesIds: SagaKey[]
  /** The date their newest recording is shelved on. */
  shelvedAt: Date
  /** Hearted recordings plus hearted sagas. */
  favoriteCount: Count
  /** The mean of the stars given to their recordings and sagas. Absent when
   *  nothing of theirs is rated. */
  averageRating?: number
}

/** What the world knows of a narrator: their face, at `narrators/{key}`,
 *  shared by every reader and holding no reference to any. No model call
 *  builds it: Wikipedia is asked for the portrait, by name, the first time
 *  somebody opens the narrator's page. Never exposed through library sharing. */
export type Narrator = {
  key: NarratorKey
  name: NarratorName
  portraitUrl?: PortraitUrl
  /** When Wikipedia was last asked for a portrait it did not have. Absent once
   *  one is found. */
  portraitSoughtAt?: Date
}

/** A narrator the reader hearted: theirs alone, never shared. Absent when they
 *  have not, rather than stored as "not hearted". */
export type NarratorFavorite = { userId: UserId; narratorKey: NarratorKey; favoritedAt: Date }
