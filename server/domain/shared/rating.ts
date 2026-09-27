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
