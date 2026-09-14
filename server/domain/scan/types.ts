import type { Brand } from 'ts-brand'
import type { Genre, Isbn13, PageCount, Publisher, Synopsis } from '~/domain/book/types'
import type { SeriesId, SeriesName, VolumeKind, VolumeNumber } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, Year } from '~/domain/shared/types'

/** SHA-256 of the submitted image. The cache key, so the same photo never pays
 *  for the model twice. */
export type ImageHash = Brand<string, 'ImageHash'>

/** The language the scan answers in. Same set the app is localized into: free
 *  text comes back in the reader's language, not the cover's. */
export type ScanLanguage = Language

/** What the model says it read on the cover, after enrichment.
 *
 *  `recognized: false` is a first-class outcome rather than an error: a photo of
 *  a table is a perfectly ordinary thing for a camera to capture, and it must
 *  come back as "nothing here" rather than as a failure the app has to explain. */
export type ScanResult = {
  recognized: boolean
  title: BookTitle | ''
  authors: AuthorName[]
  publisher?: Publisher
  firstPublishedIn?: Year
  synopsis?: Synopsis
  genres: Genre[]
  pageCount?: PageCount
  isbn13?: Isbn13
  series?: ScannedSeries
}

/** The saga the scanned book belongs to, as the enrichment step resolved it.
 *  Absent for a standalone book, which is most of them.
 *
 *  The id is carried here rather than recomputed by the caller: it is derived
 *  from the saga name AND the author, and only the scan holds both at once. The
 *  app hands it straight back to `addBook`, so a scanned book joins the very
 *  catalogue the scan built. */
export type ScannedSeries = {
  id: SeriesId
  name: SeriesName
  volume?: VolumeNumber
  kind: VolumeKind
}

/** A cached scan. Keyed by image AND language: the same cover scanned in two
 *  languages must not serve one language's synopsis to the other. */
export type CachedScan = {
  imageHash: ImageHash
  language: ScanLanguage
  result: ScanResult
  cachedAt: Date
}

/** What one Gemini step consumed. Thinking tokens bill at the output rate and
 *  are the largest line on a scan, so they are kept apart rather than folded
 *  into the output count: the allowance and the price are sized on them. */
export type AiStepUsage = {
  promptTokens: number
  outputTokens: number
  thinkingTokens: number
}

/** What the calls of one scan consumed. A step that never ran — a cache hit, an
 *  unrecognized cover skipping enrichment, a saga already catalogued — is absent
 *  rather than zero, so the metrics can tell "did not run" from "was free". */
export type ScanUsage = {
  vision?: AiStepUsage
  enrichment?: AiStepUsage
  catalogue?: AiStepUsage
}
