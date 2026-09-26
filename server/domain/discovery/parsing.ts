import { AudibleAsin } from '~/domain/audible/primitives'
import { Isbn13 } from '~/domain/book/primitives'
import { ReleaseDate, VolumeNumber } from '~/domain/series/primitives'
import { BookTitle } from '~/domain/shared/primitives'
import { optionally } from '~/utils/input'
import type { VolumeOutput } from './schemas'
import type { FoundVolume } from './types'

/** Every volume of the model's answer, one per number — the first listed wins —
 *  or nothing without a title or a number. Every other field is dropped on its
 *  own when it does not validate: a hallucinated ISBN must not cost the reader
 *  a real volume. */
export const volumesFrom = (raw: readonly VolumeOutput[]): FoundVolume[] => {
  const volumes = new Map<number, FoundVolume>()
  for (const entry of raw) {
    const number = optionally(entry.number, VolumeNumber)
    const title = optionally(entry.title, BookTitle)
    if (number === undefined || !title || volumes.has(number)) continue
    volumes.set(number, {
      number,
      title,
      date: optionally(entry.date, ReleaseDate),
      isbn13: optionally(entry.isbn13, Isbn13),
      asin: optionally(entry.asin, AudibleAsin),
    })
  }
  return [...volumes.values()].sort((left, right) => left.number - right.number)
}
