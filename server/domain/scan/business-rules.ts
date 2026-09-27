import type { DetectedBox } from '~/domain/scan/types'

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
