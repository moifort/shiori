import type { Book, ReadingStatus } from '~/domain/book/types'

/** When the book last changed status, for the ordering above. A record from
 *  before the stamp existed answers with the date its status implies — finished
 *  for a read book, started for one in progress, added for one on the pile —
 *  which is when that status was in fact set. */
export const statusChangedAtOf = (
  book: Pick<Book, 'status' | 'addedAt' | 'startedAt' | 'finishedAt' | 'statusChangedAt'>,
): Date => {
  if (book.statusChangedAt) return book.statusChangedAt
  if (book.status === 'read') return book.finishedAt ?? book.addedAt
  if (book.status === 'reading') return book.startedAt ?? book.addedAt
  return book.addedAt
}

/** The stamp a status write leaves. Only a real move is stamped: choosing the
 *  status the book already has says nothing new, and must not lift its saga to
 *  the top of the library. */
export const statusStampAfterChange = (
  book: Pick<Book, 'status'>,
  next: ReadingStatus,
  now: Date,
): { statusChangedAt?: Date } => (book.status === next ? {} : { statusChangedAt: now })

/** The dates a status change implies. Reading dates are a consequence of moving
 *  the book, never something the reader types: asking for them would mean asking
 *  twice for the same fact.
 *
 *  Going back to `to-read` clears both dates. It is the reader saying the
 *  reading did not happen, and keeping a finish date on an unread book would
 *  surface it in reading statistics forever. */
export const datesAfterStatusChange = (
  book: Pick<Book, 'status' | 'startedAt' | 'finishedAt'>,
  next: ReadingStatus,
  now: Date,
): { startedAt?: Date; finishedAt?: Date } => {
  if (next === 'to-read') return { startedAt: undefined, finishedAt: undefined }
  if (next === 'reading' || next === 'dropped')
    return { startedAt: book.startedAt ?? now, finishedAt: undefined }
  // Finishing a book that was never marked as started still has a start: the
  // reader read it, they just never told the app. Stamping both keeps the
  // statistics honest rather than leaving a finished book with no beginning.
  return { startedAt: book.startedAt ?? now, finishedAt: book.finishedAt ?? now }
}

/** How far ahead of the server a typed date may sit: the reader's phone picks
 *  "today" on its own clock, which can run ahead. */
const CLOCK_DRIFT_MS = 86_400_000

/** The reading dates in the order a book lives through them. */
const READING_DATES = ['addedAt', 'startedAt', 'finishedAt'] as const

/** The reading dates a reader corrected by hand, or `bad-dates` when they cannot
 *  be true: a date that does not parse, one in the future, two typed together
 *  out of order, or a date the status does not carry — a book on the pile was
 *  never opened, and only a read one was finished.
 *
 *  A typed date is never refused for contradicting one already stored: it is
 *  the reader's latest word, and the stored dates follow it. A start set before
 *  the arrival brings the arrival back to it; a start set after the finish
 *  carries the finish along; and so on down the line, added, started, finished.
 *
 *  Correcting the date that marks the current status — the finish of a read
 *  book, the start of one in progress, the arrival of one on the pile — also
 *  moves the status stamp the library is ordered on: the reader is saying when
 *  that move happened. A date carried along by another moves it the same way.
 *  A dropped book keeps its stamp, since no typed date says when it was
 *  dropped. */
export const datesAfterCorrection = (
  book: Pick<Book, 'status' | 'addedAt' | 'startedAt' | 'finishedAt'>,
  typed: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>>,
  now: Date,
):
  | Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt' | 'statusChangedAt'>>
  | 'bad-dates' => {
  const latest = now.getTime() + CLOCK_DRIFT_MS
  const unbelievable = (date?: Date) =>
    date !== undefined && (Number.isNaN(date.getTime()) || date.getTime() > latest)
  if (Object.values(typed).some(unbelievable)) return 'bad-dates'
  if (typed.startedAt && book.status === 'to-read') return 'bad-dates'
  if (typed.finishedAt && book.status !== 'read') return 'bad-dates'
  const typedInOrder = READING_DATES.flatMap((field) => typed[field] ?? [])
  if (typedInOrder.some((date, index) => index > 0 && date < typedInOrder[index - 1]))
    return 'bad-dates'

  const dates: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>> = {
    addedAt: book.addedAt,
    startedAt: book.startedAt,
    finishedAt: book.finishedAt,
    ...typed,
  }
  const moved: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>> = { ...typed }
  READING_DATES.forEach((field, index) => {
    const anchor = typed[field]
    if (!anchor) return
    READING_DATES.forEach((other, otherIndex) => {
      const date = dates[other]
      if (!date || typed[other]) return
      const outOfOrder = otherIndex < index ? date > anchor : otherIndex > index && date < anchor
      if (!outOfOrder) return
      dates[other] = anchor
      moved[other] = anchor
    })
  })

  const marking = { read: moved.finishedAt, reading: moved.startedAt, 'to-read': moved.addedAt }
  const stamp = book.status === 'dropped' ? undefined : marking[book.status]
  return { ...moved, ...(stamp ? { statusChangedAt: stamp } : {}) }
}

/** The reading dates a reader set on a book before saving it — on the scan
 *  review — or `bad-dates` when they cannot be true, by the same measure as a
 *  correction of a book catalogued a moment ago in that status. */
export const datesOnArrival = (
  status: ReadingStatus,
  typed: Partial<Pick<Book, 'startedAt' | 'finishedAt'>>,
  now: Date,
): Partial<Pick<Book, 'startedAt' | 'finishedAt'>> | 'bad-dates' =>
  datesAfterCorrection({ status, addedAt: now }, typed, now) === 'bad-dates' ? 'bad-dates' : typed

/** Everything a move to `next` writes on the book: the status, the reading
 *  dates it implies and, for a real move, the stamp that lifts its saga. */
export const statusMoveOf = (
  book: Pick<Book, 'status' | 'startedAt' | 'finishedAt'>,
  next: ReadingStatus,
  now: Date,
): { status: ReadingStatus; startedAt?: Date; finishedAt?: Date; statusChangedAt?: Date } => ({
  status: next,
  ...datesAfterStatusChange(book, next, now),
  ...statusStampAfterChange(book, next, now),
})
