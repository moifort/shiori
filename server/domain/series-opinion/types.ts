import type { StarRating } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
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
}
