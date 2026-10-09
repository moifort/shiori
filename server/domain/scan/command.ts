import { AuthorCommand } from '~/domain/author/command'
import { authorKeyOf } from '~/domain/author/primitives'
import { AuthorQuery } from '~/domain/author/query'
import { BookCommand } from '~/domain/book/command'
import {
  BookLanguageValue,
  GenreValue,
  Isbn13,
  MAX_SUBGENRES,
  PageCount,
  Publisher,
  Subgenre,
  Synopsis,
} from '~/domain/book/primitives'
import type { BookLanguage, Isbn13 as Isbn13Type } from '~/domain/book/types'
import {
  boxOf,
  heldFormatOf,
  inReadingOrder,
  MAX_DETECTED_BOOKS,
} from '~/domain/scan/business-rules'
import { generate } from '~/domain/scan/gemini'
import * as repository from '~/domain/scan/infrastructure/repository'
import { hashImage } from '~/domain/scan/primitives'
import {
  audioCataloguePrompt,
  candidatesPrompt,
  cataloguePrompt,
  enrichmentPrompt,
  MAX_CANDIDATES,
  shelfPrompt,
  visionPrompt,
} from '~/domain/scan/prompts'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import {
  CANDIDATES_SCHEMA,
  CATALOGUE_SCHEMA,
  ENRICHMENT_SCHEMA,
  SHELF_SCHEMA,
  VISION_SCHEMA,
} from '~/domain/scan/schemas'
import { STUBBED_SCAN, STUBBED_SHELF } from '~/domain/scan/stub'
import type {
  AiStepUsage,
  EditionHints,
  ScanLanguage,
  ScanResult,
  ScanUsage,
  SeenOnShelf,
  TitleCandidate,
} from '~/domain/scan/types'
import { withoutDuplicateVolumes } from '~/domain/series/business-rules'
import { SeriesCommand } from '~/domain/series/command'
import {
  isAudioSeries,
  keyWithAuthorReversed,
  SeriesDescription,
  SeriesName,
  seriesKeyOf,
  VolumeKindValue,
  VolumeNumber,
} from '~/domain/series/primitives'
import type { Series, SeriesId, SeriesName as SeriesNameValue, Volume } from '~/domain/series/types'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import { bareTitleOf } from '~/domain/shared/saga-title'
import type {
  AuthorName as AuthorNameValue,
  BookTitle as BookTitleValue,
} from '~/domain/shared/types'
import { config } from '~/system/config'
import { createLogger } from '~/system/logger'
import { isPresent, optionally as optional } from '~/utils/input'

const logger = createLogger('scan')

type VisionOutput = {
  recognized: boolean
  format?: string | null
  title: string
  authors: string[]
  publisher?: string | null
  language?: string | null
  seriesName?: string | null
  volumeNumber?: number | null
}

type ShelfOutput = {
  books?: {
    box_2d?: number[]
    title?: string | null
    authors?: string[]
    format?: string | null
    publisher?: string | null
    language?: string | null
    seriesName?: string | null
    volumeNumber?: number | null
  }[]
}

type EnrichmentOutput = {
  title: string
  authors: string[]
  seriesName?: string | null
  volumeNumber?: number | null
  volumeKind?: string | null
  firstPublishedIn?: number | null
  genre?: string | null
  subgenres: string[]
  pageCount?: number | null
  isbn13?: string | null
  regularEditionIsbn13?: string | null
  synopsis?: string | null
}

type CandidatesOutput = {
  candidates?: {
    title: string
    authors: string[]
    firstPublishedIn?: number | null
    seriesName?: string | null
    volumeNumber?: number | null
  }[]
}

type CatalogueOutput = {
  name: string
  author: string
  description?: string | null
  volumes: { kind: string; number?: number | null; title: string; publishedIn?: number | null }[]
}

export namespace ScanCommand {
  /** Read a cover and produce a reviewable record.
   *
   *  `cacheHit` is what the quota is metered on: a cover already scanned costs
   *  nothing, so it must not spend anyone's allowance. Only a scan that really
   *  reached Gemini is billed to us, and only that one is billed to the caller.
   */
  export const scanWithCache = async (
    image: Buffer,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; cacheHit: boolean; usage: ScanUsage }> => {
    // End-to-end runs answer with a fixed book instead of calling Gemini: the
    // models cost money, take seconds and never answer twice the same, none of
    // which a release gate can rely on. Counted as a real scan (cacheHit false)
    // so the quota path stays the one production takes.
    //
    // `import.meta.dev` is compile-time, so this branch is tree-shaken out of a
    // built bundle: no environment variable can turn the stub on in production.
    if (import.meta.dev && config().scanStub)
      return { result: STUBBED_SCAN, cacheHit: false, usage: {} }

    const imageHash = hashImage(image)
    const cached = await repository.findBy(imageHash, language)
    if (cached) return { result: cached.result, cacheHit: true, usage: {} }

    const { result: seen, usage: vision } = await readCover(image, language)
    // Nothing recognized: skip enrichment (pointless) and skip caching, so a
    // fresh attempt on a better photo starts over rather than reusing a miss.
    if (!seen.recognized) return { result: seen, cacheHit: false, usage: { vision } }

    const { result: enriched, regularEdition, usage: enrichment } = await enrich(seen, language)
    // Cached with the rest, so the same cover scanned again probes nothing.
    const result = { ...enriched, coverUrl: await coverOf(enriched.isbn13, regularEdition) }

    // Best-effort cache: a failed write only costs a re-scan on the next hit.
    repository
      .save({ imageHash, language, result, cachedAt: new Date() })
      .catch((error) => logger.warn('scan cache write failed', { error }))

    const { catalogue, author } = await catalogueWhatOpensNext(result, language, true)
    return { result, cacheHit: false, usage: { vision, enrichment, catalogue, author } }
  }

  /** A book named rather than photographed: the reader typed a title, and the
   *  grounded step does the rest, exactly as it does after a cover was read.
   *  Never cached — a typed string has no image to hash and is rarely typed
   *  twice — and always metered as a real scan, since it always calls the model.
   *
   *  `authorPage: false` leaves the author's page to its first opening, for a
   *  lookup the reader did not ask for: a Découvrir preview only shows a book. */
  export const lookUpTitle = async (
    title: BookTitleValue,
    language: ScanLanguage,
    { authorPage = true }: { authorPage?: boolean } = {},
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const named: ScanResult = { recognized: true, title, authors: [], subgenres: [] }
    const {
      result: enriched,
      regularEdition,
      usage: enrichment,
    } = await enrich(named, language, 'typed')
    const result = { ...enriched, coverUrl: await coverOf(enriched.isbn13, regularEdition) }
    const { catalogue, author } = await catalogueWhatOpensNext(result, language, authorPage)
    return { result, usage: { enrichment, catalogue, author } }
  }

  /** A book already named — its title, author, format and edition language
   *  known, as a volume the release watch announced is — described as a
   *  scanned one is: the grounded step fills in its summary, genre, pages and
   *  ISBN, and its published cover is looked up. Nothing else is built: the
   *  saga it belongs to is already known, and its author's page is left to its
   *  first opening, since the reader is only looking. */
  export const lookUpEdition = async (
    seen: ScanResult,
    language: ScanLanguage,
    hints?: EditionHints,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const {
      result: enriched,
      regularEdition,
      usage: enrichment,
    } = await enrich(seen, language, 'cover', hints)
    const result = { ...enriched, coverUrl: await coverOf(enriched.isbn13, regularEdition) }
    return { result, usage: { enrichment } }
  }

  /** A book ticked on a shelf photo, described as a scanned cover is once it
   *  was read: the grounded step, the published cover, and the saga's and
   *  author's pages when nobody built them — what the reader opens next is the
   *  same whether the book came alone or with its shelf. Unlike
   *  `lookUpEdition`, whose saga the release watch already knows. Never cached:
   *  there is no image of this one book to hash. */
  export const describeDetected = async (
    seen: ScanResult,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const { result: enriched, regularEdition, usage: enrichment } = await enrich(seen, language)
    const result = { ...enriched, coverUrl: await coverOf(enriched.isbn13, regularEdition) }
    const { catalogue, author } = await catalogueWhatOpensNext(result, language, true)
    return { result, usage: { enrichment, catalogue, author } }
  }

  /** Every book of a shelf photo, read as the cover's first step reads one:
   *  ungrounded, printed text only. Nothing is enriched here — the reader
   *  first says which books they want, and only those are paid for. */
  export const detectBooks = async (
    image: Buffer,
    language: ScanLanguage,
  ): Promise<{ books: SeenOnShelf[]; usage?: AiStepUsage }> => {
    if (import.meta.dev && config().scanStub) return { books: STUBBED_SHELF }

    const { value, usage } = await generate<ShelfOutput>({
      step: 'shelf',
      parts: [
        { inline_data: { mime_type: 'image/jpeg', data: image.toString('base64') } },
        { text: shelfPrompt(language) },
      ],
      responseSchema: SHELF_SCHEMA,
    })
    const books = (value.books ?? []).map(parsedShelfBook).filter(isPresent)
    return { books: inReadingOrder(books).slice(0, MAX_DETECTED_BOOKS), usage }
  }

  /** A book without a frame cannot be cropped or pointed at, so it is dropped;
   *  a book without a title is kept, for the reader to name. */
  const parsedShelfBook = (
    raw: NonNullable<ShelfOutput['books']>[number],
  ): SeenOnShelf | undefined => {
    const box = boxOf(raw.box_2d ?? [])
    if (!box) return undefined
    const book: SeenOnShelf = {
      title: optional(raw.title, BookTitle),
      authors: parsedAuthors(raw.authors ?? []),
      ...heldFormatOf(raw.format),
      publisher: optional(raw.publisher, Publisher),
      language: optional(raw.language, BookLanguageValue),
      seriesName: optional(raw.seriesName, SeriesName),
      volume: optional(raw.volumeNumber, VolumeNumber),
      box,
    }
    // A field the spine did not print is absent, not present-and-undefined:
    // the checklist reads "no title" as a missing key.
    return Object.fromEntries(
      Object.entries(book).filter(([, value]) => value !== undefined),
    ) as SeenOnShelf
  }

  /** The books a typed title may mean, for the reader to pick one before the
   *  full lookup runs. One ungrounded call, so it answers in seconds; the book
   *  picked is then looked up by `lookUpTitle` as "title — author", which names
   *  it without ambiguity. An empty list is an ordinary answer: nothing matched. */
  export const findCandidates = async (
    title: BookTitleValue,
    language: ScanLanguage,
  ): Promise<{ candidates: TitleCandidate[]; usage?: AiStepUsage }> => {
    if (import.meta.dev && config().scanStub)
      return {
        candidates: [
          {
            title: BookTitle(STUBBED_SCAN.title || 'Le Nom du vent'),
            authors: STUBBED_SCAN.authors,
            firstPublishedIn: STUBBED_SCAN.firstPublishedIn,
            seriesName: STUBBED_SCAN.series?.name,
            volume: STUBBED_SCAN.series?.volume,
          },
        ],
      }

    const { value, usage } = await generate<CandidatesOutput>({
      step: 'candidates',
      parts: [{ text: candidatesPrompt(title, language) }],
      responseSchema: CANDIDATES_SCHEMA,
    })
    const candidates = (value.candidates ?? [])
      .map(parsedCandidate)
      .filter(isPresent)
      // The prompt asks for one entry per work, and the model still lists an
      // edition twice now and then: the same title by the same author is one book.
      .filter(
        (candidate, index, all) => all.findIndex((other) => sameBook(other, candidate)) === index,
      )
      .slice(0, MAX_CANDIDATES)
    return { candidates, usage }
  }

  const parsedCandidate = (
    raw: NonNullable<CandidatesOutput['candidates']>[number],
  ): TitleCandidate | undefined => {
    const title = optional(raw.title, BookTitle)
    if (!title) return undefined
    return {
      title,
      authors: parsedAuthors(raw.authors),
      firstPublishedIn: optional(raw.firstPublishedIn, Year),
      seriesName: optional(raw.seriesName, SeriesName),
      volume: optional(raw.volumeNumber, VolumeNumber),
    }
  }

  const folded = (text: string) =>
    text
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
      .trim()

  const sameBook = (a: TitleCandidate, b: TitleCandidate) =>
    folded(a.title) === folded(b.title) && folded(a.authors[0] ?? '') === folded(b.authors[0] ?? '')

  /** Step 1. Not grounded: the answer is in the image, and letting the model
   *  search here invites it to "correct" a cover it read correctly. */
  const readCover = async (image: Buffer, language: ScanLanguage) => {
    const { value, usage } = await generate<VisionOutput>({
      step: 'vision',
      parts: [
        { inline_data: { mime_type: 'image/jpeg', data: image.toString('base64') } },
        { text: visionPrompt(language) },
      ],
      responseSchema: VISION_SCHEMA,
    })

    if (!value.recognized || !value.title.trim()) {
      return {
        result: { recognized: false, title: '' as const, authors: [], subgenres: [] },
        usage,
      }
    }

    const authors = parsedAuthors(value.authors)
    const held = heldFormatOf(value.format)
    return {
      result: {
        recognized: true,
        title: BookTitle(value.title),
        authors,
        ...held,
        publisher: optional(value.publisher, Publisher),
        language: optional(value.language, BookLanguageValue),
        subgenres: [],
        // What the cover printed of its saga — "Volume 2" — goes on to step 2,
        // which needs it to tell this volume from the others titled the same.
        series: parsedSeries(
          {
            seriesName: value.seriesName,
            volumeNumber: value.volumeNumber,
            volumeKind: value.volumeNumber != null ? 'main' : null,
          },
          authors,
          held.format,
        ),
      } satisfies ScanResult,
      usage,
    }
  }

  /** Step 2. Grounded, and the only step that can find a series the cover never
   *  mentioned — which most of them do not. */
  const enrich = async (
    seen: ScanResult,
    language: ScanLanguage,
    source: 'cover' | 'typed' = 'cover',
    hints?: EditionHints,
  ) => {
    const { value, usage } = await generate<EnrichmentOutput>({
      step: 'enrichment',
      parts: [{ text: enrichmentPrompt(seen, language, source, hints) }],
      responseSchema: ENRICHMENT_SCHEMA,
      grounded: true,
    })

    const authors = parsedAuthors(value.authors)
    const series = parsedSeries(value, authors.length > 0 ? authors : seen.authors, seen.format)
    return {
      result: {
        recognized: true,
        // The review shows the saga and the volume beside the title, as the
        // book will.
        title: bareTitleOf(optional(value.title, BookTitle) ?? seen.title, series?.name),
        authors: authors.length > 0 ? authors : seen.authors,
        format: seen.format,
        media: seen.media,
        publisher: seen.publisher,
        // Kept from step 1 rather than asked again: the language of the edition
        // is a fact about the object photographed, and the grounded step answers
        // about the work — which is a different question with a different answer.
        language: seen.language,
        firstPublishedIn: optional(value.firstPublishedIn, Year),
        synopsis: optional(value.synopsis, Synopsis),
        genre: optional(value.genre, GenreValue),
        subgenres: (value.subgenres ?? [])
          .map((subgenre) => optional(subgenre, Subgenre))
          .filter(isPresent)
          .slice(0, MAX_SUBGENRES),
        pageCount: optional(value.pageCount, PageCount),
        // Another volume's ISBN, though the model was told it is not this one,
        // would draw that volume's cover: no cover beats a wrong one.
        isbn13: notAnotherVolume(optional(value.isbn13, Isbn13), hints),
        series,
      } satisfies ScanResult,
      // Not part of the result: the book is the edition the reader holds, and
      // this one only lends it a cover.
      regularEdition: notAnotherVolume(optional(value.regularEditionIsbn13, Isbn13), hints),
      usage,
    }
  }

  const notAnotherVolume = (isbn13: Isbn13Type | undefined, hints: EditionHints | undefined) =>
    isbn13 && hints?.siblings.some((sibling) => sibling.isbn13 === isbn13) ? undefined : isbn13

  /** The published cover of the edition the reader holds, drawn with its regular
   *  edition's cover when it is a special one. A collector's own cover is often a
   *  3D shot of the object, served identically by every source, where the regular
   *  edition shows the same artwork flat. Its own cover stays the fallback. */
  const coverOf = async (
    isbn13: Isbn13Type | undefined,
    regularEdition: Isbn13Type | undefined,
  ) => {
    if (regularEdition && regularEdition !== isbn13) {
      const regularCover = await publishedCoverOf(regularEdition)
      if (regularCover) return regularCover
    }
    return isbn13 ? await publishedCoverOf(isbn13) : undefined
  }

  /** What the reader is likely to open next, built while they review the book
   *  rather than when they tap it: the saga's page and the author's, both
   *  shared, both paid once for everyone. The two calls run side by side, so
   *  the author costs the scan no more time than the saga already did.
   *
   *  Only a scan asks: an Audible import names a whole library at once, and
   *  its sagas and authors are built when somebody opens them. */
  const catalogueWhatOpensNext = async (
    result: ScanResult,
    language: ScanLanguage,
    authorPage: boolean,
  ) => {
    const [catalogue, author] = await Promise.all([
      catalogueSeriesIfNeeded(result, language),
      authorPage ? catalogueAuthorIfNeeded(result, language) : undefined,
    ])
    return { catalogue, author }
  }

  /** The first author's page, when nobody has opened it yet. A co-author's
   *  waits for its first opening: one grounded call per scan is the budget. */
  const catalogueAuthorIfNeeded = async (result: ScanResult, language: ScanLanguage) => {
    const name = result.authors[0]
    if (!name) return undefined

    const key = authorKeyOf(name)
    if (await AuthorQuery.byKey(key)) return undefined
    // The model already failed on this author: the reader's refresh asks again.
    if (await AuthorQuery.lastMiss(key)) return undefined

    const { usage } = await AuthorCommand.catalogueFromWeb(key, name, language, result.language)
    return usage
  }

  /** Step 3, and only when it buys something: a standalone book or a saga
   *  already catalogued in this edition skips it entirely. The catalogue is
   *  shared, so this is paid once for every reader of that saga in that
   *  language, ever. */
  const catalogueSeriesIfNeeded = async (result: ScanResult, language: ScanLanguage) => {
    const series = result.series
    if (!series || result.authors.length === 0) return undefined

    // A cover that does not say its language is presumed in the reader's, as
    // the app presumes it when the book is added: that is the edition whose
    // catalogue the reader opens next.
    const edition = result.language ?? language
    if (await SeriesCommand.isCatalogued({ id: series.id, language: edition })) return undefined
    // The same saga under its author's names in the other order: the book
    // joins it when it is added (`filedAfterCatalogues`), so it is not paid for
    // twice.
    const reversed = keyWithAuthorReversed(series.id)
    if (reversed && (await SeriesCommand.isCatalogued({ id: reversed, language: edition })))
      return undefined

    const { usage } = await catalogueSeries(
      series.id,
      series.name,
      result.authors[0],
      language,
      edition,
    )
    return usage
  }

  /** The catalogue call on its own, for a saga named but never described — or
   *  described once and asked again. The scan runs it as its third step; the
   *  series screen runs it for a saga an Audible import named, since an import
   *  describes nothing, and again when the reader asks for a fresh catalogue.
   *
   *  `editionLanguage` is the edition on the shelf, whose catalogue this is:
   *  the volumes out in that language, under their titles there. Absent — a
   *  volume that records no language — the reader's language stands in for
   *  the model, and the catalogue is stored as that of no language, the one
   *  such volumes read.
   *
   *  Never throws: a failed catalogue must not fail the scan that asked for it.
   *  The reader still gets their book, and the saga is catalogued by the next
   *  scan or opening that touches it. An empty catalogue is not stored either:
   *  it would mask the saga as known and stop any later attempt with better
   *  grounding. The empty answer is remembered beside it instead, so the next
   *  opening does not wait on the same call. `usage` says what the call cost whenever it answered, stored or
   *  not. */
  export const catalogueSeries = async (
    seriesId: SeriesId,
    name: SeriesNameValue,
    author: AuthorNameValue,
    language: ScanLanguage,
    editionLanguage?: BookLanguage,
  ): Promise<{ series?: Series; usage?: AiStepUsage }> => {
    try {
      const { value, usage } = await generate<CatalogueOutput>({
        step: 'catalogue',
        parts: [
          {
            text: isAudioSeries(seriesId)
              ? audioCataloguePrompt(name, author, language, editionLanguage)
              : cataloguePrompt(name, author, language, editionLanguage),
          },
        ],
        responseSchema: CATALOGUE_SCHEMA,
        grounded: true,
      })

      const volumes = withoutDuplicateVolumes(value.volumes.map(parsedVolume).filter(isPresent))
      if (volumes.length === 0) {
        await SeriesCommand.recordNothingFound(
          { id: seriesId, language: editionLanguage },
          new Date(),
        )
        return { usage }
      }

      const series = await SeriesCommand.catalogue({
        id: seriesId,
        ...(editionLanguage ? { language: editionLanguage } : {}),
        name: SeriesName(value.name),
        author: AuthorName(value.author),
        description: optional(value.description, SeriesDescription),
        volumes,
        catalogedAt: new Date(),
      } satisfies Series)
      await nameBooksAfter(series)
      return { series, usage }
    } catch (error) {
      logger.error('series catalogue generation failed', { error, series: name })
      return {}
    }
  }

  /** Every reader's volumes of a saga just catalogued in one edition take the
   *  name that edition's catalogue gives it, as the saga screen shows it — and
   *  only those: the same saga is called otherwise in another language. A
   *  failure leaves them named as they were, and the catalogue stands. */
  const nameBooksAfter = async (series: Series) => {
    try {
      await BookCommand.nameSeries(series, series.name)
    } catch (error) {
      logger.warn('saga name not written into its books', { error, series: series.id })
    }
  }

  const parsedVolume = (raw: CatalogueOutput['volumes'][number]): Volume | undefined => {
    const title = optional(raw.title, BookTitle)
    if (!title) return undefined
    try {
      return {
        title,
        kind: VolumeKindValue(raw.kind),
        number: optional(raw.number, VolumeNumber),
        publishedIn: optional(raw.publishedIn, Year),
      }
    } catch (error) {
      // One malformed volume drops out rather than losing the whole catalogue,
      // and the model output that produced it is reported.
      logger.warn('malformed catalogue volume dropped', { error, volume: raw })
      return undefined
    }
  }

  const parsedSeries = (
    value: Pick<EnrichmentOutput, 'seriesName' | 'volumeNumber' | 'volumeKind'>,
    authors: ScanResult['authors'],
    format: ScanResult['format'],
  ): ScanResult['series'] => {
    const name = optional(value.seriesName, SeriesName)
    // Without an author there is no stable key, so the saga cannot be catalogued
    // or rejoined later. Dropping it beats inventing an id nothing else shares.
    if (!name || authors.length === 0) return undefined
    return {
      // A format the cover did not settle is a printed book, as `BookCommand.add`
      // would file it; the reader's pick realigns the saga when the book is saved.
      id: seriesKeyOf(name, authors[0], format ?? 'book'),
      name,
      volume: optional(value.volumeNumber, VolumeNumber),
      // A series the model found but could not classify is a main volume: it is
      // what a numbered cycle is, and the alternative would bury it in related
      // works where the reader would not look for it.
      kind: optional(value.volumeKind, VolumeKindValue) ?? 'main',
    }
  }

  const parsedAuthors = (raw: string[] | undefined): ScanResult['authors'] =>
    (raw ?? []).map((author) => optional(author, AuthorName)).filter(isPresent)
}
