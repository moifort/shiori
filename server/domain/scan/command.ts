import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage, Isbn13 as Isbn13Type } from '~/domain/book/types'
import {
  editionsToShow,
  inReadingOrder,
  MAX_DETECTED_BOOKS,
  searchedQueryOf,
  typedQueryOf,
  withTypedCandidate,
} from '~/domain/scan/business-rules'
import { bnfEditionsOf } from '~/domain/scan/infrastructure/bnf'
import * as repository from '~/domain/scan/infrastructure/repository'
import {
  authorsFrom,
  candidatesFrom,
  catalogueVolumeFrom,
  coverReadingFrom,
  type Described,
  enrichmentFrom,
  libraryDescriptionFrom,
  shelfBookFrom,
} from '~/domain/scan/parsing'
import { hashImage } from '~/domain/scan/primitives'
import {
  audioCataloguePrompt,
  candidatesPrompt,
  cataloguePrompt,
  editionsPrompt,
  enrichmentPrompt,
  MAX_CANDIDATES,
  shelfPrompt,
  visionPrompt,
} from '~/domain/scan/prompts'
import {
  CANDIDATES_SCHEMA,
  CATALOGUE_SCHEMA,
  type CandidatesOutput,
  type CatalogueOutput,
  EDITIONS_SCHEMA,
  type EditionsOutput,
  ENRICHMENT_SCHEMA,
  type EnrichmentOutput,
  SHELF_SCHEMA,
  type ShelfOutput,
  VISION_SCHEMA,
  type VisionOutput,
} from '~/domain/scan/schemas'
import { STUBBED_SCAN, STUBBED_SHELF } from '~/domain/scan/stub'
import type {
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
  SeriesDescription,
  SeriesName,
  seriesIdOf,
} from '~/domain/series/primitives'
import type { SagaKey, Series, SeriesName as SeriesNameValue } from '~/domain/series/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type {
  AuthorName as AuthorNameValue,
  BookTitle as BookTitleValue,
} from '~/domain/shared/types'
import { config } from '~/system/config'
import { generate } from '~/system/gemini'
import { type AiStepUsage, summedUsage } from '~/system/gemini/usage'
import { createLogger } from '~/system/logger'
import { isPresent, optionally as optional } from '~/utils/input'
import { slugify } from '~/utils/slug'

const logger = createLogger('scan')

/** A described book and what describing it cost. */
type Enriched = Described & { usage?: AiStepUsage }

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
    const result = await withPublishedCover(enriched, regularEdition)

    // Best-effort cache: a failed write only costs a re-scan on the next hit.
    repository
      .save({ imageHash, language, result, cachedAt: new Date() })
      .catch((error) => logger.warn('scan cache write failed', { error }))

    // The saga's page and the author's wait for their first opening: the review
    // shows neither, and a reader who never taps them never pays for them.
    return { result, cacheHit: false, usage: { vision, enrichment } }
  }

  /** A book named rather than photographed: the reader typed a title, and the
   *  grounded step does the rest, exactly as it does after a cover was read.
   *  Never cached — a typed string has no image to hash and is rarely typed
   *  twice — and always metered as a real scan, since it always calls the model.
   *  The saga's page and the author's wait for their first opening, as a
   *  cover's do. */
  export const lookUpTitle = async (
    title: BookTitleValue,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const typed = typedQueryOf(title)
    const named: ScanResult = {
      recognized: true,
      title: BookTitle(typed.title),
      authors: authorsFrom(typed.author ? [typed.author] : []),
      subgenres: [],
    }
    const {
      result: enriched,
      regularEdition,
      usage: enrichment,
    } = await enrich(named, language, 'typed')
    const result = await withPublishedCover(enriched, regularEdition)
    return { result, usage: { enrichment } }
  }

  /** A book already named — its title, author, format and edition language
   *  known, as a volume the release watch announced is — described as a
   *  scanned one is: its summary, genre, pages and ISBN filled in, and its
   *  published cover looked up. Nothing else is built: the saga it belongs to
   *  is already known, and its author's page is left to its first opening,
   *  since the reader is only looking.
   *
   *  A French edition is described from the BnF's catalogue first, which costs
   *  half a thousandth of a euro where the grounded step bills six Google
   *  searches, eight cents. The grounded step runs only when the catalogue
   *  left the book undescribed — see `describedFromLibrary`. */
  export const lookUpEdition = async (
    seen: ScanResult,
    language: ScanLanguage,
    hints?: EditionHints,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const library = await describedFromLibrary(seen, language, hints)
    const described = library.found ?? (await enrich(seen, language, 'cover', hints))
    const { result: enriched, regularEdition } = described
    const result = await withPublishedCover(enriched, regularEdition)
    const enrichment = library.found ? library.usage : summedUsage(library.usage, described.usage)
    return { result, usage: { enrichment } }
  }

  /** A book described from the editions the BnF lists for it, with no web
   *  search: the model, ungrounded, picks the edition by its index and writes
   *  the synopsis from the publishers' blurbs. `found` is absent whenever the
   *  grounded step should run instead — and `usage` says what asking cost.
   *
   *  Only a printed French edition is asked about: the BnF is the French legal
   *  deposit, and holds no recording. The description stands only with an
   *  edition picked, and with a synopsis — the catalogue's, or the one the
   *  record already carries, which a lookup that found none leaves in place.
   *  A book never described, with no blurb at the BnF, is looked up on the web,
   *  so it is never left without a summary. */
  const describedFromLibrary = async (
    seen: ScanResult,
    language: ScanLanguage,
    hints?: EditionHints,
  ): Promise<{ found?: Enriched; usage?: AiStepUsage }> => {
    const author = seen.authors[0]
    const edition = seen.language ?? language
    if (!seen.title || !author || edition !== 'fr' || seen.format === 'audiobook') return {}

    const { series } = seen
    const titledAfterSaga = series !== undefined && slugify(series.name) === slugify(seen.title)
    const editions = editionsToShow(
      await bnfEditionsOf({
        title: seen.title,
        author,
        volume: titledAfterSaga ? series.volume : undefined,
      }),
      seen,
      hints,
    )
    if (editions.length === 0) return {}

    try {
      const { value, usage } = await generate<EditionsOutput>({
        step: 'enrichment-library',
        parts: [{ text: editionsPrompt(seen, editions, language, hints) }],
        responseSchema: EDITIONS_SCHEMA,
      })
      const found = libraryDescriptionFrom(value, seen, editions)
      return found ? { usage, found: { ...found, usage } } : { usage }
    } catch (error) {
      // The grounded step is asked next; a refusal it shares, it reports.
      logger.warn('library description failed', { error, title: seen.title })
      return {}
    }
  }

  /** A book ticked on a shelf photo, described as a scanned cover is once it
   *  was read: the grounded step and the published cover. Its saga's and
   *  author's pages are left to their first opening, as an Audible import
   *  leaves them: a shelf names twenty books at once, and building both pages
   *  for each doubled what the shelf cost. Never cached: there is no image of
   *  this one book to hash.
   *
   *  Only builds that predate `addDetectedBook` still ask. */
  export const describeDetected = async (
    seen: ScanResult,
    language: ScanLanguage,
  ): Promise<{ result: ScanResult; usage: ScanUsage }> => {
    if (import.meta.dev && config().scanStub) return { result: STUBBED_SCAN, usage: {} }

    const { result: enriched, regularEdition, usage: enrichment } = await enrich(seen, language)
    const result = await withPublishedCover(enriched, regularEdition)
    return { result, usage: { enrichment } }
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
    const books = (value.books ?? []).map(shelfBookFrom).filter(isPresent)
    return { books: inReadingOrder(books).slice(0, MAX_DETECTED_BOOKS), usage }
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
    const candidates = candidatesFrom(value)
    const searched = searchedQueryOf(title)
    const typed: TitleCandidate = {
      title: BookTitle(searched.title),
      authors: authorsFrom(searched.author ? [searched.author] : []),
    }
    return {
      candidates: withTypedCandidate(
        candidates,
        typed,
        searched.author !== undefined,
        MAX_CANDIDATES,
      ),
      usage,
    }
  }

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

    return { result: coverReadingFrom(value), usage }
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

    return { ...enrichmentFrom(value, seen, hints), usage }
  }

  /** The published cover of the edition the reader holds, drawn with its regular
   *  edition's cover when it is a special one. A collector's own cover is often a
   *  3D shot of the object, served identically by every source, where the regular
   *  edition shows the same artwork flat. Its own cover stays the fallback. */
  const coverOf = async (
    isbn13: Isbn13Type | undefined,
    regularEdition: Isbn13Type | undefined,
  ) => {
    if (regularEdition && regularEdition !== isbn13) {
      const regularCover = await BookQuery.publishedCoverOf(regularEdition)
      if (regularCover) return regularCover
    }
    return isbn13 ? await BookQuery.publishedCoverOf(isbn13) : undefined
  }

  /** A described book with its published cover: see `coverOf`. */
  const withPublishedCover = async (
    enriched: ScanResult,
    regularEdition: Isbn13Type | undefined,
  ): Promise<ScanResult> => ({
    ...enriched,
    coverUrl: await coverOf(enriched.isbn13, regularEdition),
  })

  /** The catalogue call on its own, for a saga named but never described — or
   *  described once and asked again. The series screen runs it for a saga an Audible import named, since an import
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
    saga: SagaKey,
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
            text: isAudioSeries(saga)
              ? audioCataloguePrompt(name, author, language, editionLanguage)
              : cataloguePrompt(name, author, language, editionLanguage),
          },
        ],
        responseSchema: CATALOGUE_SCHEMA,
        grounded: true,
      })

      const volumes = withoutDuplicateVolumes(
        value.volumes.map(catalogueVolumeOrDropped).filter(isPresent),
      )
      if (volumes.length === 0) {
        await SeriesCommand.recordNothingFound({ saga, language: editionLanguage }, new Date())
        return { usage }
      }

      const series = await SeriesCommand.catalogue({
        id: seriesIdOf(saga, editionLanguage),
        saga,
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
      await BookCommand.nameSeries(series.id, series.name)
    } catch (error) {
      logger.warn('saga name not written into its books', { error, series: series.id })
    }
  }

  /** One malformed volume drops out rather than losing the whole catalogue,
   *  and the model output that produced it is reported. */
  const catalogueVolumeOrDropped = (raw: CatalogueOutput['volumes'][number]) => {
    try {
      return catalogueVolumeFrom(raw)
    } catch (error) {
      logger.warn('malformed catalogue volume dropped', { error, volume: raw })
      return undefined
    }
  }
}
