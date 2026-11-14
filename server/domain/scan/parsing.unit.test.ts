import { describe, expect, test } from 'bun:test'
import { Isbn13, PageCount, Publisher, Synopsis } from '~/domain/book/primitives'
import {
  authorsFrom,
  candidatesFrom,
  catalogueVolumeFrom,
  coverReadingFrom,
  enrichmentFrom,
  libraryDescriptionFrom,
  seriesFrom,
  shelfBookFrom,
} from '~/domain/scan/parsing'
import type { EditionHints, LibraryEdition, ScanResult } from '~/domain/scan/types'
import { seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

const rothfuss = AuthorName('Patrick Rothfuss')
const isbn = Isbn13('9782070612758')
const otherIsbn = Isbn13('9782266320481')

const seen: ScanResult = {
  recognized: true,
  title: BookTitle('Le Nom du vent'),
  authors: [rothfuss],
  publisher: Publisher('Brage lonne'),
  language: 'fr',
  media: ['print'],
  subgenres: [],
}

const enrichment = {
  title: 'Le Nom du vent',
  authors: ['Patrick Rothfuss'],
  subgenres: ['Fantasy épique'],
}

describe('coverReadingFrom', () => {
  test('reads nothing from a cover the model did not recognize, or left untitled', () => {
    const nothing: ScanResult = { recognized: false, title: '', authors: [], subgenres: [] }
    expect(coverReadingFrom({ recognized: false, title: 'Dune', authors: [] })).toEqual(nothing)
    expect(coverReadingFrom({ recognized: true, title: '  ', authors: ['X'] })).toEqual(nothing)
  })

  test('reads the printed fields, an ebook as a book on a screen, a volume as a main one', () => {
    const read = coverReadingFrom({
      recognized: true,
      title: 'Le Nom du vent',
      authors: ['Patrick Rothfuss', ''],
      format: 'ebook',
      publisher: 'Bragelonne',
      language: 'fr',
      seriesName: 'Chronique du tueur de roi',
      volumeNumber: 1,
    })
    expect(read).toMatchObject({
      recognized: true,
      title: 'Le Nom du vent',
      authors: ['Patrick Rothfuss'],
      format: 'book',
      media: ['digital'],
      publisher: 'Bragelonne',
      language: 'fr',
      subgenres: [],
      series: { name: 'Chronique du tueur de roi', volume: 1, kind: 'main' },
    })
  })

  test('drops what does not validate', () => {
    const read = coverReadingFrom({
      recognized: true,
      title: 'Dune',
      authors: ['Frank Herbert'],
      language: 'klingon',
      publisher: null,
    })
    expect(read.language).toBeUndefined()
    expect(read.publisher).toBeUndefined()
    expect(read.series).toBeUndefined()
  })
})

describe('enrichmentFrom', () => {
  test('keeps the edition language and media read on the cover', () => {
    const { result } = enrichmentFrom({ ...enrichment, pageCount: 662, isbn13: isbn }, seen)
    expect(result).toMatchObject({
      recognized: true,
      title: 'Le Nom du vent',
      language: 'fr',
      media: ['print'],
      pageCount: 662,
      isbn13: isbn,
      subgenres: ['Fantasy Épique'],
    })
  })

  test('falls back on the authors read on the cover when the search names none', () => {
    expect(enrichmentFrom({ ...enrichment, authors: [] }, seen).result.authors).toEqual([rothfuss])
  })

  test('mends the publisher the cover split, takes the lookup’s when none was read', () => {
    expect(enrichmentFrom({ ...enrichment, publisher: 'Bragelonne' }, seen).result.publisher).toBe(
      Publisher('Bragelonne'),
    )
    const unread = { ...seen, publisher: undefined }
    expect(
      enrichmentFrom({ ...enrichment, publisher: 'Bragelonne' }, unread).result.publisher,
    ).toBe(Publisher('Bragelonne'))
  })

  test('settles a comic album named by a subgenre, which leaves the list', () => {
    const { result } = enrichmentFrom({ ...enrichment, subgenres: ['Bande dessinée'] }, seen)
    expect(result.format).toBe('bande-dessinee')
    expect(result.subgenres).toEqual([])
  })

  test('strips the saga from the title', () => {
    const { result } = enrichmentFrom(
      {
        ...enrichment,
        title: 'Chronique du tueur de roi, Tome 1 : Le Nom du vent',
        seriesName: 'Chronique du tueur de roi',
        volumeNumber: 1,
      },
      seen,
    )
    expect(result.title).toBe(BookTitle('Le Nom du vent'))
    expect(result.series?.volume).toBe(VolumeNumber(1))
  })

  test('drops an ISBN that is another volume the reader holds', () => {
    const hints: EditionHints = { siblings: [{ kind: 'main', isbn13: isbn }] }
    const described = enrichmentFrom(
      { ...enrichment, isbn13: isbn, regularEditionIsbn13: isbn },
      seen,
      hints,
    )
    expect(described.result.isbn13).toBeUndefined()
    expect(described.regularEdition).toBeUndefined()
    expect(
      enrichmentFrom({ ...enrichment, regularEditionIsbn13: otherIsbn }, seen).regularEdition,
    ).toBe(otherIsbn)
  })
})

describe('libraryDescriptionFrom', () => {
  const editions: LibraryEdition[] = [
    {
      isbn13: isbn,
      title: 'Le Nom du vent — Tome 1',
      publisher: 'Bragelonne',
      pageCount: PageCount(662),
    },
    { isbn13: otherIsbn, title: 'Le Nom du vent' },
  ]

  test('describes the book as the picked edition records it', () => {
    const described = libraryDescriptionFrom(
      { edition: 0, regularEdition: 1, synopsis: 'Kvothe raconte.', firstPublishedIn: 2007 },
      seen,
      editions,
    )
    expect(described?.result).toMatchObject({
      title: 'Le Nom du vent',
      publisher: 'Bragelonne',
      pageCount: 662,
      isbn13: isbn,
      synopsis: 'Kvothe raconte.',
      firstPublishedIn: 2007,
    })
    expect(described?.regularEdition).toBe(otherIsbn)
  })

  test('names no regular edition when it is the edition picked', () => {
    const described = libraryDescriptionFrom(
      { edition: 0, regularEdition: 0, synopsis: 'Kvothe raconte.' },
      seen,
      editions,
    )
    expect(described?.regularEdition).toBeUndefined()
  })

  test('answers nothing without an edition picked, or without any synopsis', () => {
    expect(
      libraryDescriptionFrom({ edition: null, synopsis: 'Texte.' }, seen, editions),
    ).toBeUndefined()
    expect(
      libraryDescriptionFrom({ edition: 7, synopsis: 'Texte.' }, seen, editions),
    ).toBeUndefined()
    expect(libraryDescriptionFrom({ edition: 0 }, seen, editions)).toBeUndefined()
  })

  test('keeps the synopsis the record already carries when the catalogue has none', () => {
    const described = libraryDescriptionFrom(
      { edition: 1 },
      { ...seen, synopsis: Synopsis('Déjà décrit.') },
      editions,
    )
    expect(described?.result.synopsis).toBeUndefined()
    expect(described?.result.isbn13).toBe(otherIsbn)
  })
})

describe('shelfBookFrom', () => {
  test('drops a book without a frame', () => {
    expect(shelfBookFrom({ title: 'Dune', authors: ['Frank Herbert'] })).toBeUndefined()
    expect(shelfBookFrom({ box_2d: [0, 0, 0, 0], title: 'Dune' })).toBeUndefined()
  })

  test('keeps an untitled book, its unprinted fields absent rather than undefined', () => {
    const book = shelfBookFrom({ box_2d: [0, 0, 500, 100], title: null, format: 'manga' })
    expect(book).toEqual({
      authors: [],
      format: 'manga',
      box: { x: 0, y: 0, width: 0.1, height: 0.5 },
    })
    expect(book && 'title' in book).toBe(false)
  })
})

describe('candidatesFrom', () => {
  test('drops untitled candidates and the same book listed twice', () => {
    const candidates = candidatesFrom({
      candidates: [
        { title: 'Dune', authors: ['Frank Herbert'], firstPublishedIn: 1965 },
        { title: '', authors: ['Nobody'] },
        { title: 'DUNE', authors: ['Frank Herbert'] },
        { title: 'Dune', authors: ['Brian Herbert'], seriesName: 'Dune', volumeNumber: 1 },
      ],
    })
    expect(candidates).toEqual([
      {
        title: BookTitle('Dune'),
        authors: [AuthorName('Frank Herbert')],
        firstPublishedIn: Year(1965),
      },
      {
        title: BookTitle('Dune'),
        authors: [AuthorName('Brian Herbert')],
        seriesName: expect.anything(),
        volume: VolumeNumber(1),
      },
    ])
  })

  test('answers none to an answer without candidates', () => {
    expect(candidatesFrom({})).toEqual([])
  })
})

describe('catalogueVolumeFrom', () => {
  test('reads a volume, nothing without a title', () => {
    expect(
      catalogueVolumeFrom({ kind: 'main', number: 2, title: 'La Peur du sage', publishedIn: 2011 }),
    ).toEqual({
      title: BookTitle('La Peur du sage'),
      kind: 'main',
      number: VolumeNumber(2),
      publishedIn: Year(2011),
    })
    expect(catalogueVolumeFrom({ kind: 'main', title: '' })).toBeUndefined()
  })

  test('throws on a kind that is none, for the caller to drop the volume', () => {
    expect(() => catalogueVolumeFrom({ kind: 'prequel-ish', title: 'Un tome' })).toThrow()
  })
})

describe('seriesFrom', () => {
  test('keys the saga by its name, first author and format', () => {
    const series = seriesFrom(
      { seriesName: 'Dune', volumeNumber: 1 },
      [AuthorName('Frank Herbert')],
      undefined,
    )
    expect(series).toEqual({
      saga: seriesKeyOf(series?.name ?? ('' as never), AuthorName('Frank Herbert'), 'book'),
      name: expect.anything(),
      volume: VolumeNumber(1),
      kind: 'main',
    })
  })

  test('drops a saga without a name or without an author', () => {
    expect(seriesFrom({ seriesName: null }, [rothfuss], 'book')).toBeUndefined()
    expect(seriesFrom({ seriesName: 'Dune' }, [], 'book')).toBeUndefined()
  })

  test('keeps the kind the model gave', () => {
    expect(
      seriesFrom({ seriesName: 'Dune', volumeKind: 'novella' }, [rothfuss], 'book')?.kind,
    ).toBe('novella')
  })
})

describe('authorsFrom', () => {
  test('drops the names that are none', () => {
    expect(authorsFrom(['Frank Herbert', '', '  '])).toEqual([AuthorName('Frank Herbert')])
    expect(authorsFrom(undefined)).toEqual([])
  })
})
