import {
  formatNamedByLookup,
  formatSettledBySubgenres,
  mendedSpelling,
  titleWithoutAuthor,
} from '~/domain/book/business-rules'
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
import type { Isbn13 as Isbn13Type, Publisher as PublisherType } from '~/domain/book/types'
import { boxOf, heldFormatOf } from '~/domain/scan/business-rules'
import type {
  CandidatesOutput,
  CatalogueOutput,
  EditionsOutput,
  EnrichmentOutput,
  ShelfOutput,
  VisionOutput,
} from '~/domain/scan/schemas'
import type {
  EditionHints,
  LibraryEdition,
  ScanResult,
  SeenOnShelf,
  TitleCandidate,
} from '~/domain/scan/types'
import { SeriesName, seriesKeyOf, VolumeKindValue, VolumeNumber } from '~/domain/series/primitives'
import type { Volume } from '~/domain/series/types'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import { bareTitleOf } from '~/domain/shared/saga-title'
import { isPresent, optionally as optional } from '~/utils/input'
import { foldedText } from '~/utils/slug'

/** What a described book is, before its cover is looked up. `regularEdition`
 *  is not part of the result: the book is the edition the reader holds, and
 *  that one only lends it a cover. */
export type Described = {
  result: ScanResult
  regularEdition?: Isbn13Type
}

/** Step 1's answer: what the cover printed, or nothing recognized. What the
 *  cover printed of its saga — "Volume 2" — goes on to step 2, which needs it
 *  to tell this volume from the others titled the same. */
export const coverReadingFrom = (value: VisionOutput): ScanResult => {
  if (!value.recognized || !value.title.trim())
    return { recognized: false, title: '', authors: [], subgenres: [] }

  const authors = authorsFrom(value.authors)
  const held = heldFormatOf(value.format)
  return {
    recognized: true,
    title: BookTitle(value.title),
    authors,
    ...held,
    publisher: optional(value.publisher, Publisher),
    language: optional(value.language, BookLanguageValue),
    subgenres: [],
    series: seriesFrom(
      {
        seriesName: value.seriesName,
        volumeNumber: value.volumeNumber,
        volumeKind: value.volumeNumber != null ? 'main' : null,
      },
      authors,
      held.format,
    ),
  }
}

/** Step 2's answer, laid over what step 1 read. */
export const enrichmentFrom = (
  value: EnrichmentOutput,
  seen: ScanResult,
  hints?: EditionHints,
): Described => {
  const parsed = authorsFrom(value.authors)
  const authors = parsed.length > 0 ? parsed : seen.authors
  // The search knows a comic album where the cover left it a book: it names
  // the format, or a subgenre does, and leaves the list.
  const { format, subgenres } = formatSettledBySubgenres(
    formatNamedByLookup(seen.format, value.format),
    subgenresFrom(value.subgenres),
  )
  const series = seriesFrom(value, authors, format)
  return {
    result: {
      recognized: true,
      // The review shows the saga, the volume and the authors beside the
      // title, as the book will.
      title: titleWithoutAuthor(
        bareTitleOf(optional(value.title, BookTitle) ?? seen.title, series?.name),
        authors,
      ),
      authors,
      format,
      media: seen.media,
      publisher: mendedOrHeld(seen.publisher, optional(value.publisher, Publisher)),
      // Kept from step 1 rather than asked again: the language of the edition
      // is a fact about the object photographed, and the grounded step answers
      // about the work — which is a different question with a different answer.
      language: seen.language,
      firstPublishedIn: optional(value.firstPublishedIn, Year),
      synopsis: optional(value.synopsis, Synopsis),
      genre: optional(value.genre, GenreValue),
      subgenres: subgenres.slice(0, MAX_SUBGENRES),
      pageCount: optional(value.pageCount, PageCount),
      // Another volume's ISBN, though the model was told it is not this one,
      // would draw that volume's cover: no cover beats a wrong one.
      isbn13: notAnotherVolume(optional(value.isbn13, Isbn13), hints),
      series,
    },
    regularEdition: notAnotherVolume(optional(value.regularEditionIsbn13, Isbn13), hints),
  }
}

/** The library step's answer: the book as the edition the model picked
 *  describes it, or nothing when it picked none, or when neither the answer
 *  nor the record carries a synopsis — the grounded step then runs instead. */
export const libraryDescriptionFrom = (
  value: EditionsOutput,
  seen: ScanResult,
  editions: readonly LibraryEdition[],
): Described | undefined => {
  const picked = value.edition != null ? editions[value.edition] : undefined
  const synopsis = optional(value.synopsis, Synopsis)
  if (!picked || !(synopsis ?? seen.synopsis)) return undefined
  const regular = value.regularEdition != null ? editions[value.regularEdition] : undefined
  // The catalogue files an album under "Bande dessinée" as the web does.
  const { format, subgenres } = formatSettledBySubgenres(
    formatNamedByLookup(seen.format, value.format),
    subgenresFrom(value.subgenres),
  )
  return {
    result: {
      recognized: true,
      // What the spine misread with a space inside a word, the
      // catalogue spells whole.
      title: mendedSpelling(seen.title || undefined, catalogueTitleOf(picked)) ?? seen.title,
      authors: seen.authors,
      format,
      media: seen.media,
      publisher: mendedOrHeld(seen.publisher, optional(picked.publisher, Publisher)),
      language: seen.language,
      firstPublishedIn: optional(value.firstPublishedIn, Year),
      synopsis,
      genre: optional(value.genre, GenreValue),
      subgenres: subgenres.slice(0, MAX_SUBGENRES),
      pageCount: picked.pageCount,
      isbn13: picked.isbn13,
      series: seen.series,
    },
    regularEdition: regular?.isbn13 !== picked.isbn13 ? regular?.isbn13 : undefined,
  }
}

/** A book of a shelf photo. A book without a frame cannot be cropped or
 *  pointed at, so it is dropped; a book without a title is kept, for the
 *  reader to name. */
export const shelfBookFrom = (
  raw: NonNullable<ShelfOutput['books']>[number],
): SeenOnShelf | undefined => {
  const box = boxOf(raw.box_2d ?? [])
  if (!box) return undefined
  const book: SeenOnShelf = {
    title: optional(raw.title, BookTitle),
    authors: authorsFrom(raw.authors ?? []),
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

/** The candidates of the model's answer, those without a title dropped. The
 *  prompt asks for one entry per work, and the model still lists an edition
 *  twice now and then: the same title by the same author is one book. */
export const candidatesFrom = (value: CandidatesOutput): TitleCandidate[] =>
  (value.candidates ?? [])
    .map(candidateFrom)
    .filter(isPresent)
    .filter(
      (candidate, index, all) => all.findIndex((other) => sameBook(other, candidate)) === index,
    )

const candidateFrom = (
  raw: NonNullable<CandidatesOutput['candidates']>[number],
): TitleCandidate | undefined => {
  const title = optional(raw.title, BookTitle)
  if (!title) return undefined
  return {
    title,
    authors: authorsFrom(raw.authors),
    firstPublishedIn: optional(raw.firstPublishedIn, Year),
    seriesName: optional(raw.seriesName, SeriesName),
    volume: optional(raw.volumeNumber, VolumeNumber),
  }
}

const sameBook = (a: TitleCandidate, b: TitleCandidate) =>
  foldedText(a.title) === foldedText(b.title) &&
  foldedText(a.authors[0] ?? '') === foldedText(b.authors[0] ?? '')

/** One volume of a catalogue answer, or nothing without a title. Throws on a
 *  kind that is none: the caller drops that volume and reports the answer. */
export const catalogueVolumeFrom = (
  raw: CatalogueOutput['volumes'][number],
): Volume | undefined => {
  const title = optional(raw.title, BookTitle)
  if (!title) return undefined
  return {
    title,
    kind: VolumeKindValue(raw.kind),
    number: optional(raw.number, VolumeNumber),
    publishedIn: optional(raw.publishedIn, Year),
  }
}

/** The saga a model named for a book. */
export const seriesFrom = (
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
    saga: seriesKeyOf(name, authors[0], format ?? 'book'),
    name,
    volume: optional(value.volumeNumber, VolumeNumber),
    // A series the model found but could not classify is a main volume: it is
    // what a numbered cycle is, and the alternative would bury it in related
    // works where the reader would not look for it.
    kind: optional(value.volumeKind, VolumeKindValue) ?? 'main',
  }
}

/** The authors a model named, those that are not one dropped. */
export const authorsFrom = (raw: string[] | undefined): ScanResult['authors'] =>
  (raw ?? []).map((author) => optional(author, AuthorName)).filter(isPresent)

/** The subgenres a model named, those that are not one dropped. */
const subgenresFrom = (named: readonly (string | null)[] | null | undefined) =>
  (named ?? []).map((subgenre) => optional(subgenre, Subgenre)).filter(isPresent)

/** The publisher the scan read, but as a lookup spells it whole when the
 *  read split a word (`mendedSpelling`); the lookup's when none was read. */
const mendedOrHeld = (held: PublisherType | undefined, found: PublisherType | undefined) =>
  held ? (mendedSpelling(held, found) ?? held) : found

/** A catalogue edition's title proper, without what its record adds after
 *  a dash: the volume, its own title, a subtitle. */
const catalogueTitleOf = (edition: LibraryEdition) =>
  optional(edition.title?.split(' — ')[0], BookTitle)

const notAnotherVolume = (isbn13: Isbn13Type | undefined, hints: EditionHints | undefined) =>
  isbn13 && hints?.siblings.some((sibling) => sibling.isbn13 === isbn13) ? undefined : isbn13
