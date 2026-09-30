import type { StarRating } from '~/domain/shared/types'

/** How a heart and stars relate, on a book as on a saga. Shared rather than
 *  owned by either: both domains apply it, and neither may import the other's
 *  rules for it. */

/** The rating a heart gives something not rated yet, or rated too low to
 *  hold one: the top of the scale. */
export const HEART_RATING = 5 as StarRating

/** The fewest stars a heart can sit on. A reader may love a book they would
 *  not call flawless, so three and four stars hold a heart as five do; below
 *  three, a heart and the stars would say two things the reader cannot both
 *  mean. */
export const HEART_FLOOR = 3

/** Whether a heart survives a new rating: only on three stars or more. Stars
 *  given by hand keep a heart but never grant one — the heart stays the
 *  reader's own gesture. */
export const favoriteAfterRating = (
  favorite: boolean | undefined,
  rating: StarRating | undefined,
): true | undefined =>
  favorite === true && rating !== undefined && rating >= HEART_FLOOR ? true : undefined

/** The stars under a heart just given: the reader's own when they can hold
 *  it, else the top of the scale. */
export const ratingUnderHeart = (rating: StarRating | undefined): StarRating =>
  rating !== undefined && rating >= HEART_FLOOR ? rating : HEART_RATING

/** Where a judgement sits among the favourites, best first: the reader's own
 *  heart; then a saga's full marks lent to a volume left unrated, which a row
 *  draws as the saga's heart; then five stars down to one, given or lent alike.
 *  Undefined for what the reader has not judged, which the favourites leave
 *  out. */
export const lovedRankOf = (judged: {
  favorite?: boolean
  rating?: StarRating
  lentRating?: StarRating
}): number | undefined => {
  if (judged.favorite === true) return 0
  if (judged.rating === undefined && judged.lentRating === HEART_RATING) return 1
  const rating = judged.rating ?? judged.lentRating
  return rating === undefined ? undefined : 2 + HEART_RATING - rating
}

/** The favourites view of a list: what the reader judged, hearts first and
 *  then the stars from five down to one, `tie` ordering each rank. Done on the
 *  server because the list is paginated. */
export const lovedFirst = <Row>(
  rows: readonly Row[],
  rankOf: (row: Row) => number | undefined,
  tie: (left: Row, right: Row) => number,
): Row[] =>
  rows
    .map((row) => ({ row, rank: rankOf(row) }))
    .filter((ranked): ranked is { row: Row; rank: number } => ranked.rank !== undefined)
    .sort((left, right) => left.rank - right.rank || tie(left.row, right.row))
    .map(({ row }) => row)
