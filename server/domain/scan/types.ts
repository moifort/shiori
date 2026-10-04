import type { Brand } from 'ts-brand'
import type {
  BookFormat,
  BookLanguage,
  BookMedium,
  CoverUrl,
  Genre,
  Isbn13,
  PageCount,
  Publisher,
  Subgenre,
  Synopsis,
} from '~/domain/book/types'
import type {
  ReleaseDate,
  SeriesId,
  SeriesName,
  VolumeKind,
  VolumeNumber,
} from '~/domain/series/types'
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
  /** Absent when the model could not tell, and on scans cached before the format
   *  was read — the reader picks it on the review screen either way. */
  format?: BookFormat
  /** Where the photographed copy is held, when the cover said: a cover shown on
   *  an e-reader is held on a screen. Absent otherwise — the save files it on
   *  paper. */
  media?: BookMedium[]
  publisher?: Publisher
  firstPublishedIn?: Year
  synopsis?: Synopsis
  genre?: Genre
  /** Absent on a scan cached before subgenres existed; read it as empty. */
  subgenres?: Subgenre[]
  pageCount?: PageCount
  /** The language of the photographed edition, read off the cover in step 1 —
   *  the object on the shelf, not the language the work was written in. Absent
   *  when the cover does not settle it, and on scans cached before it was read. */
  language?: BookLanguage
  isbn13?: Isbn13
  /** The publisher's cover, looked up by ISBN rather than asked of the model — a
   *  model asked for an image URL invents one. Absent without an ISBN, or when
   *  no cover was found. */
  coverUrl?: CoverUrl
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

/** What else is known of a volume looked up by name, said to the model so it
 *  settles on this volume of this edition: the volumes of a comic are often
 *  all titled after the saga, and the title alone named volume 1 for each. */
export type EditionHints = {
  /** The ISBN the release watch found for this volume, for the model to check. */
  watchedIsbn13?: Isbn13
  /** When this volume came out in this edition, as the release watch found it. */
  releasedOn?: ReleaseDate
  /** Other volumes of the saga the reader holds: their ISBNs are not this one's. */
  siblings: { volume?: VolumeNumber; kind: VolumeKind; isbn13: Isbn13 }[]
}

/** One book a typed title may mean, offered for the reader to pick before the
 *  full lookup runs. Just enough to tell two books apart — the record itself is
 *  built by `lookUpTitle` once the reader chose. */
export type TitleCandidate = {
  title: BookTitle
  authors: AuthorName[]
  firstPublishedIn?: Year
  seriesName?: SeriesName
  volume?: VolumeNumber
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
 *  into the output count: the allowance and the price are sized on them.
 *
 *  `searches` is the Google searches a grounded step ran, billed per search on
 *  top of the tokens and past a few thousand a month the larger of the two. An
 *  ungrounded step is always zero. */
export type AiStepUsage = {
  promptTokens: number
  outputTokens: number
  thinkingTokens: number
  searches: number
}

/** What the calls of one scan consumed. A step that never ran — a cache hit, an
 *  unrecognized cover skipping enrichment, a saga already catalogued — is absent
 *  rather than zero, so the metrics can tell "did not run" from "was free". */
export type ScanUsage = {
  vision?: AiStepUsage
  enrichment?: AiStepUsage
  catalogue?: AiStepUsage
  /** The author's page, built alongside the saga's when nobody had opened it. */
  author?: AiStepUsage
}

/** Where a book sits in the reader's photo, each side a fraction of the photo:
 *  `x` and `y` are its top-left corner, `0...1` from the left and the top. */
export type DetectedBox = { x: number; y: number; width: number; height: number }

/** One book read off a shelf photo: only what its spine or cover prints, and
 *  where it is. `title` is absent when the model could not read it — the
 *  reader types it on the checklist. */
export type SeenOnShelf = {
  title?: BookTitle
  authors: AuthorName[]
  publisher?: Publisher
  language?: BookLanguage
  format?: BookFormat
  media?: BookMedium[]
  seriesName?: SeriesName
  volume?: VolumeNumber
  box: DetectedBox
}

/** A book of the photo as the checklist shows it: whether the reader already
 *  owns it decides whether it comes ticked. */
export type DetectedBook = SeenOnShelf & { owned: boolean }
