import {
  BookFormatValue,
  GenreValue,
  Isbn13,
  MAX_SUBGENRES,
  PageCount,
  Publisher,
  Subgenre,
  Synopsis,
} from '~/domain/book/primitives'
import { generate } from '~/domain/scan/gemini'
import * as repository from '~/domain/scan/infrastructure/repository'
import { publishedCoverOf } from '~/domain/scan/open-library'
import { hashImage } from '~/domain/scan/primitives'
import { cataloguePrompt, enrichmentPrompt, visionPrompt } from '~/domain/scan/prompts'
import { CATALOGUE_SCHEMA, ENRICHMENT_SCHEMA, VISION_SCHEMA } from '~/domain/scan/schemas'
import { STUBBED_SCAN } from '~/domain/scan/stub'
import type { ScanLanguage, ScanResult, ScanUsage } from '~/domain/scan/types'
import { SeriesCommand } from '~/domain/series/command'
import {
  SeriesDescription,
  SeriesName,
  seriesKeyOf,
  VolumeKindValue,
  VolumeNumber,
} from '~/domain/series/primitives'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, Volume } from '~/domain/series/types'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
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
  seriesName?: string | null
  volumeNumber?: number | null
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
  synopsis?: string | null
}

type CatalogueOutput = {
  name: string
  author: string
  description?: string | null
  volumes: { kind: string; number?: number | null; title: string; publishedIn?: number | null }[]
}

export namespace Scan {
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

    const { result: enriched, usage: enrichment } = await enrich(seen, language)
    // Cached with the rest, so the same cover scanned again probes nothing.
    const coverUrl = enriched.isbn13 ? await publishedCoverOf(enriched.isbn13) : undefined
    const result = { ...enriched, coverUrl }

    // Best-effort cache: a failed write only costs a re-scan on the next hit.
    repository
      .save({ imageHash, language, result, cachedAt: new Date() })
      .catch((error) => logger.warn(`cache write failed: ${error}`))

    const catalogue = await catalogueSeriesIfNeeded(result, language)
    return { result, cacheHit: false, usage: { vision, enrichment, catalogue } }
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

    if (!value.recognized || !value.title.trim()) {
      return {
        result: { recognized: false, title: '' as const, authors: [], subgenres: [] },
        usage,
      }
    }

    return {
      result: {
        recognized: true,
        title: BookTitle(value.title),
        authors: parsedAuthors(value.authors),
        format: optional(value.format, BookFormatValue),
        publisher: optional(value.publisher, Publisher),
        subgenres: [],
      } satisfies ScanResult,
      usage,
    }
  }

  /** Step 2. Grounded, and the only step that can find a series the cover never
   *  mentioned — which most of them do not. */
  const enrich = async (seen: ScanResult, language: ScanLanguage) => {
    const { value, usage } = await generate<EnrichmentOutput>({
      step: 'enrichment',
      parts: [{ text: enrichmentPrompt(seen.title, seen.authors, language) }],
      responseSchema: ENRICHMENT_SCHEMA,
      grounded: true,
    })

    const authors = parsedAuthors(value.authors)
    return {
      result: {
        recognized: true,
        title: optional(value.title, BookTitle) ?? seen.title,
        authors: authors.length > 0 ? authors : seen.authors,
        format: seen.format,
        publisher: seen.publisher,
        firstPublishedIn: optional(value.firstPublishedIn, Year),
        synopsis: optional(value.synopsis, Synopsis),
        genre: optional(value.genre, GenreValue),
        subgenres: (value.subgenres ?? [])
          .map((subgenre) => optional(subgenre, Subgenre))
          .filter(isPresent)
          .slice(0, MAX_SUBGENRES),
        pageCount: optional(value.pageCount, PageCount),
        isbn13: optional(value.isbn13, Isbn13),
        series: parsedSeries(value, authors.length > 0 ? authors : seen.authors),
      } satisfies ScanResult,
      usage,
    }
  }

  /** Step 3, and only when it buys something: a standalone book or a saga
   *  already in the catalogue skips it entirely. The catalogue is shared, so
   *  this is paid once for every reader of that saga, ever. */
  const catalogueSeriesIfNeeded = async (result: ScanResult, language: ScanLanguage) => {
    const series = result.series
    if (!series || result.authors.length === 0) return undefined

    const seriesId = seriesKeyOf(series.name, result.authors[0])
    if (await SeriesQuery.byId(seriesId)) return undefined

    try {
      const { value, usage } = await generate<CatalogueOutput>({
        step: 'catalogue',
        parts: [{ text: cataloguePrompt(series.name, result.authors[0], language) }],
        responseSchema: CATALOGUE_SCHEMA,
        grounded: true,
      })

      const volumes = value.volumes.map(parsedVolume).filter(isPresent)
      // An empty catalogue is not worth storing: it would mask the saga as
      // "known" and stop any later scan from trying again with better grounding.
      if (volumes.length === 0) return usage

      await SeriesCommand.catalogue({
        id: seriesId,
        name: SeriesName(value.name),
        author: AuthorName(value.author),
        description: optional(value.description, SeriesDescription),
        volumes,
        catalogedAt: new Date(),
      } satisfies Series)
      return usage
    } catch (error) {
      // A failed catalogue must not fail the scan. The reader still gets their
      // book; the saga is simply catalogued on the next scan that touches it.
      logger.warn(`catalogue failed for "${series.name}": ${error}`)
      return undefined
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
    } catch {
      // One malformed volume drops out rather than losing the whole catalogue.
      return undefined
    }
  }

  const parsedSeries = (
    value: EnrichmentOutput,
    authors: ScanResult['authors'],
  ): ScanResult['series'] => {
    const name = optional(value.seriesName, SeriesName)
    // Without an author there is no stable key, so the saga cannot be catalogued
    // or rejoined later. Dropping it beats inventing an id nothing else shares.
    if (!name || authors.length === 0) return undefined
    return {
      id: seriesKeyOf(name, authors[0]),
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
