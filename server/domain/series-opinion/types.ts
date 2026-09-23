import type { BookLanguage, StarRating } from '~/domain/book/types'
import type { SeriesId, VolumeNumber } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'

/** What one reader makes of one saga.
 *
 *  Its own aggregate rather than a field on the catalogue: `series/{seriesKey}`
 *  is a fact about the world, shared by every reader of the saga, and an opinion
 *  is the one thing that must never be written there.
 *
 *  The rating is a judgement of the saga itself, deliberately not the average of
 *  the volumes: a cycle can be worth more than its books — the shape only shows
 *  at the end — or rather less, when three good volumes are followed by four
 *  that should not exist.
 *
 *  Held per saga, never per saga and language. The split the library draws by
 *  language is about editions on a shelf; an opinion is about the work, and a
 *  reader who owns Dune twice does not think twice about it. */
export type SeriesOpinion = {
  userId: UserId
  seriesId: SeriesId
  rating?: StarRating
  favorite?: boolean
  /** When the heart was given, for a friend to see what is new among the
   *  favourites. Present only beside `favorite`, and absent on hearts given
   *  before the field existed. */
  favoritedAt?: Date
  /** How many volumes the saga has, by the reader's own count, for a saga
   *  nobody has catalogued: what their screen draws the missing volumes from
   *  until the model describes it. Theirs alone — the shared catalogue is a
   *  fact about the world and a reader's guess is not written into it. As a
   *  `VolumeNumber`, since it is the number the last volume carries. */
  volumeCount?: VolumeNumber
  /** The reader set the saga aside: it leaves the sagas in progress and the
   *  finished ones, whatever its volumes say. Only the saga — its volumes keep
   *  their own statuses. Absent is following, which is what every saga starts
   *  as, so a follow again leaves nothing stored. */
  unfollowed?: true
  /** The editions of the saga the reader set aside, by language, while they
   *  follow the others: setting the English Dune aside says nothing of the
   *  French one beside it. Absent when no single edition is set aside. */
  unfollowedLanguages?: BookLanguage[]
}
