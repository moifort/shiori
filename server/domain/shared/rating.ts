import type { StarRating } from '~/domain/shared/types'

/** How a heart and stars relate, on a book as on a saga. Shared rather than
 *  owned by either: both domains apply it, and neither may import the other's
 *  rules for it. */

/** The rating a heart stands for: the top of the scale. A heart is five
 *  stars, not a second judgement beside them. */
export const HEART_RATING = 5 as StarRating

/** Whether a heart survives a new rating. Only five stars can hold one: a heart
 *  over three stars would say two things the reader cannot both mean. Five
 *  stars given by hand keep a heart but never grant one — the heart stays the
 *  reader's own gesture. */
export const favoriteAfterRating = (
  favorite: boolean | undefined,
  rating: StarRating | undefined,
): true | undefined => (favorite === true && rating === HEART_RATING ? true : undefined)
