import type { Brand } from 'ts-brand'
import type { Nationality, PortraitUrl } from '~/domain/author/types'
import type { NarratorName } from '~/domain/book/types'
import type { SagaKey } from '~/domain/series/types'
import type { Count, UserId, Year } from '~/domain/shared/types'

/** A narrator as the reader's recordings name them, folded as an author is —
 *  diacritics dropped, punctuation collapsed — so "Frédéric Kneip" and
 *  "Frederic Kneip" meet. Derived, never typed. */
export type NarratorKey = Brand<string, 'NarratorKey'>

/** A few sentences on who a narrator is: the actor or the voice, and what
 *  made their name. */
export type NarratorBiography = Brand<string, 'NarratorBiography'>

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

/** What the world knows of a narrator, at `narrators/{key}`, shared by every
 *  reader and holding no reference to any. Built as an author's catalogue is,
 *  the first time somebody opens the narrator's page: one grounded call for
 *  who they are, then Wikipedia for their face, on the page the model named.
 *  Never exposed through library sharing. */
export type Narrator = {
  key: NarratorKey
  name: NarratorName
  nationality?: Nationality
  birthYear?: Year
  deathYear?: Year
  biography?: NarratorBiography
  portraitUrl?: PortraitUrl
  /** When Wikipedia was last asked for a portrait it did not have. Absent once
   *  one is found. */
  portraitSoughtAt?: Date
  /** When the model described them. Absent on an entry holding the portrait
   *  alone, which the next opening asks the model about. */
  cataloguedAt?: Date
  /** When the model last failed or knew nothing of them: no opening asks
   *  again for a month. Absent once they are described. */
  missedAt?: Date
  /** The fields a reader corrected by hand, which no later catalogue call or
   *  portrait lookup writes over. Absent until the first correction. */
  corrected?: NarratorCorrectableField[]
}

/** What a reader may correct of a narrator: the facts and the face, as of an
 *  author. The name is the recordings'. */
export const NARRATOR_CORRECTABLE_FIELDS = [
  'nationality',
  'birthYear',
  'deathYear',
  'biography',
  'portraitUrl',
] as const
export type NarratorCorrectableField = (typeof NARRATOR_CORRECTABLE_FIELDS)[number]

/** A reader's correction of a narrator: a field absent is left alone, one set
 *  to undefined is cleared. */
export type NarratorCorrection = Partial<Pick<Narrator, NarratorCorrectableField>>

/** A narrator the reader hearted: theirs alone, never shared. Absent when they
 *  have not, rather than stored as "not hearted". */
export type NarratorFavorite = { userId: UserId; narratorKey: NarratorKey; favoritedAt: Date }
