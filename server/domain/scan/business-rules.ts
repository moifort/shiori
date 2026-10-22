import { BookFormatValue } from '~/domain/book/primitives'
import type { BookFormat, BookMedium } from '~/domain/book/types'
import { BOOK_FORMATS } from '~/domain/book/types'
import type { AiStepUsage, DetectedBox } from '~/domain/scan/types'
import { optionally } from '~/utils/input'

/** What the model may say an object is. `ebook` is not a format of the
 *  library — paper or screen is where a book is held, not what it is — but it
 *  is what a cover shown on a reader looks like, so the model keeps the word
 *  and `heldFormatOf` reads it. */
export const SEEN_FORMATS = [...BOOK_FORMATS, 'ebook'] as const

/** The format and media of what was seen: a cover on an e-reader is a book held
 *  on a screen; anything else says nothing of the medium, and the reader's
 *  save files it on paper. Also reads the scans cached when `ebook` was still a
 *  format. */
export const heldFormatOf = (
  seen: string | null | undefined,
): { format?: BookFormat; media?: BookMedium[] } => {
  if (seen === 'ebook') return { format: 'book', media: ['digital'] }
  const format = optionally(seen, BookFormatValue)
  return format ? { format } : {}
}

/** How many books one photo answers at most. Past thirty the spines are too
 *  thin to read anyway, and the checklist is longer than anyone ticks through. */
export const MAX_DETECTED_BOOKS = 30

/** Gemini's `box_2d` — `[ymin, xmin, ymax, xmax]` on a 0–1000 grid — as the
 *  fractions the app crops with. Converted here, once, so no client ever learns
 *  the model's convention. A box without area is no box: the book is dropped
 *  rather than drawn as a dot. */
export const boxOf = (box2d: readonly number[]): DetectedBox | undefined => {
  if (box2d.length !== 4 || box2d.some((value) => !Number.isFinite(value))) return undefined
  const [ymin, xmin, ymax, xmax] = box2d.map((value) => Math.min(Math.max(value, 0), 1000) / 1000)
  if (xmax <= xmin || ymax <= ymin) return undefined
  return {
    x: rounded(xmin),
    y: rounded(ymin),
    width: rounded(xmax - xmin),
    height: rounded(ymax - ymin),
  }
}

/** Four decimals: a tenth of a pixel on a 2000 px photo, and no float noise
 *  (0.25 − 0.2 is 0.04999999999999999) shipped through the API. */
const rounded = (value: number) => Math.round(value * 10_000) / 10_000

/** Left to right, top to bottom, as the reader's eye goes along a bookcase.
 *  A book joins the row of the book above it when its vertical centre falls
 *  within that row's first book: spines of uneven height stay on one shelf. */
export const inReadingOrder = <T extends { box: DetectedBox }>(books: readonly T[]): T[] => {
  const rows: T[][] = []
  for (const book of [...books].sort((a, b) => a.box.y - b.box.y)) {
    const row = rows.at(-1)
    const centre = book.box.y + book.box.height / 2
    if (row && centre < row[0].box.y + row[0].box.height) row.push(book)
    else rows.push([book])
  }
  return rows.flatMap((row) => row.sort((a, b) => a.box.x - b.box.x))
}

/** Two calls made for one step, billed as one. */
export const summedUsage = (
  first: AiStepUsage | undefined,
  second: AiStepUsage | undefined,
): AiStepUsage | undefined =>
  first && second
    ? {
        promptTokens: first.promptTokens + second.promptTokens,
        outputTokens: first.outputTokens + second.outputTokens,
        thinkingTokens: first.thinkingTokens + second.thinkingTokens,
        searches: first.searches + second.searches,
      }
    : (first ?? second)

/** The Google searches Gemini bills free each month. */
export const FREE_GEMINI_SEARCHES = 5000

/** The searches one grounded Gemini call is billed for, measured: 421 for 67
 *  calls on 2026-10-19, 450 for 107 on 2026-10-12 counting the shelf's
 *  ungrounded ones. Gemini's own figure says a fourth of it, so the bill is
 *  read from the calls instead. */
export const SEARCHES_PER_GROUNDED_CALL = 6.3

/** How far under the free searches the grounded steps move to Claude: the
 *  ratio is an average, and a shelf scan runs twenty calls in a minute. */
const FREE_SEARCHES_MARGIN = 500

/** Whether this month's grounded Gemini calls have spent the free searches,
 *  give or take the margin: past it, every search is billed, and Claude's are
 *  paid from the Anthropic credit instead. */
export const freeSearchesSpent = (groundedCalls: number): boolean =>
  groundedCalls * SEARCHES_PER_GROUNDED_CALL >= FREE_GEMINI_SEARCHES - FREE_SEARCHES_MARGIN

/** The separator the app puts between a picked title and its author. */
const TYPED_AUTHOR_SEPARATOR = ' — '

/** A typed title and the author the app names beside it. Picking a candidate,
 *  or adding a book from a saga or author page, asks "La Horde du Contrevent —
 *  Alain Damasio": the author tells the book apart, but is no part of its
 *  title. Handed over whole, the model kept the string as the title, and the
 *  record no longer matched the same book scanned on a shelf later. */
export const typedQueryOf = (query: string): { title: string; author?: string } => {
  const at = query.lastIndexOf(TYPED_AUTHOR_SEPARATOR)
  const title = query.slice(0, at).trim()
  const author = query.slice(at + TYPED_AUTHOR_SEPARATOR.length).trim()
  return at > 0 && title && author ? { title, author } : { title: query }
}
