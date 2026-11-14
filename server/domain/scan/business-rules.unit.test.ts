import { describe, expect, test } from 'bun:test'
import { Isbn13 } from '~/domain/book/primitives'
import {
  boxOf,
  EDITIONS_SHOWN,
  editionsToShow,
  heldFormatOf,
  inReadingOrder,
  searchedQueryOf,
  typedQueryOf,
  withTypedCandidate,
} from '~/domain/scan/business-rules'
import { SagaKey, SeriesName, VolumeNumber } from '~/domain/series/primitives'

describe('boxOf', () => {
  test('turns Gemini’s [ymin, xmin, ymax, xmax] on 0–1000 into fractions of the photo', () => {
    expect(boxOf([100, 200, 900, 250])).toEqual({ x: 0.2, y: 0.1, width: 0.05, height: 0.8 })
  })

  test('clamps a corner the model drew outside the photo', () => {
    expect(boxOf([-20, 950, 500, 1040])).toEqual({ x: 0.95, y: 0, width: 0.05, height: 0.5 })
  })

  test('refuses a box that is not four numbers, or has no area', () => {
    expect(boxOf([1, 2, 3])).toBeUndefined()
    expect(boxOf([100, 200, 100, 300])).toBeUndefined()
    expect(boxOf([100, 300, 200, 300])).toBeUndefined()
    expect(boxOf([100, Number.NaN, 200, 300])).toBeUndefined()
  })
})

describe('inReadingOrder', () => {
  const at = (id: string, x: number, y: number, width = 0.1, height = 0.3) => ({
    id,
    box: { x, y, width, height },
  })

  test('reads a shelf of spines left to right, whatever their heights', () => {
    const books = [
      at('c', 0.5, 0.12, 0.05, 0.7),
      at('a', 0.1, 0.1, 0.05, 0.8),
      at('b', 0.3, 0.2, 0.05, 0.6),
    ]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c'])
  })

  test('reads two shelves top to bottom, each left to right', () => {
    const books = [at('d', 0.6, 0.55), at('b', 0.6, 0.05), at('c', 0.1, 0.6), at('a', 0.1, 0.1)]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c', 'd'])
  })
})

describe('heldFormatOf', () => {
  test('reads a cover shown on an e-reader as a book held on a screen', () => {
    expect(heldFormatOf('ebook')).toEqual({ format: 'book', media: ['digital'] })
  })

  test('says nothing of the medium for anything else', () => {
    expect(heldFormatOf('manga')).toEqual({ format: 'manga' })
    expect(heldFormatOf(null)).toEqual({})
    expect(heldFormatOf('scroll')).toEqual({})
  })
})

describe('typedQueryOf', () => {
  test('splits the author the app names beside a picked title', () => {
    expect(typedQueryOf('La Horde du Contrevent — Alain Damasio')).toEqual({
      title: 'La Horde du Contrevent',
      author: 'Alain Damasio',
    })
  })

  test('cuts at the last dash, so a title holding one keeps it', () => {
    expect(typedQueryOf('Dune — Le Messie — Frank Herbert')).toEqual({
      title: 'Dune — Le Messie',
      author: 'Frank Herbert',
    })
  })

  test('leaves a title typed alone, or a dash with nothing on one side, whole', () => {
    expect(typedQueryOf('Projet dernière chance')).toEqual({ title: 'Projet dernière chance' })
    expect(typedQueryOf('— Andy Weir')).toEqual({ title: '— Andy Weir' })
    expect(typedQueryOf('Projet dernière chance — ')).toEqual({
      title: 'Projet dernière chance — ',
    })
  })
})

describe('searchedQueryOf', () => {
  test('splits an author typed after any spaced dash', () => {
    for (const dash of ['-', '–', '—'])
      expect(searchedQueryOf(`Le mensonge suffit ${dash} Christopher Bouix`)).toEqual({
        title: 'Le mensonge suffit',
        author: 'Christopher Bouix',
      })
  })

  test('leaves a hyphenated title, or a title typed alone, whole', () => {
    expect(searchedQueryOf('Spider-Man')).toEqual({ title: 'Spider-Man' })
    expect(searchedQueryOf(' Projet dernière chance ')).toEqual({ title: 'Projet dernière chance' })
    expect(searchedQueryOf('Dune - ')).toEqual({ title: 'Dune -' })
  })
})

describe('withTypedCandidate', () => {
  const found = [{ title: 'Le mensonge' }, { title: 'Mensonges' }]

  test('keeps the candidates alone when one bears the typed title', () => {
    expect(withTypedCandidate(found, { title: 'MENSONGES' }, false, 5)).toEqual(found)
  })

  test('puts the typed book first when an author was named, last otherwise', () => {
    const typed = { title: 'Le mensonge suffit' }
    expect(withTypedCandidate(found, typed, true, 5)).toEqual([typed, ...found])
    expect(withTypedCandidate(found, typed, false, 5)).toEqual([...found, typed])
  })

  test('never lets the limit cut the typed book', () => {
    expect(withTypedCandidate(found, { title: 'Autre' }, false, 2)).toEqual([
      { title: 'Le mensonge' },
      { title: 'Autre' },
    ])
  })
})

describe('editionsToShow', () => {
  const saga = { saga: SagaKey('dune'), name: SeriesName('Dune'), kind: 'main' as const }
  const edition = (volume: string | undefined, isbn13: string) => ({
    isbn13: Isbn13(isbn13),
    volume,
  })
  const tome1 = edition('1', '9782070612758')
  const tome2 = edition('2', '9782266320481')
  const unnumbered = edition(undefined, '9780306406157')

  test('keeps only this volume’s editions when the catalogue numbers any of them', () => {
    const shown = editionsToShow(
      [tome1, tome2, unnumbered],
      { series: { ...saga, volume: VolumeNumber(2) } },
      undefined,
    )
    expect(shown).toEqual([tome2])
  })

  test('keeps them all when none is numbered as this volume', () => {
    expect(editionsToShow([tome1, unnumbered], {}, undefined)).toEqual([tome1, unnumbered])
  })

  test('never shows an edition the reader holds as another volume', () => {
    const hints = { siblings: [{ kind: 'main' as const, isbn13: tome1.isbn13 }] }
    expect(editionsToShow([tome1, unnumbered], {}, hints)).toEqual([unnumbered])
  })

  test('shows at most EDITIONS_SHOWN', () => {
    const many = Array.from({ length: EDITIONS_SHOWN + 5 }, () => unnumbered)
    expect(editionsToShow(many, {}, undefined)).toHaveLength(EDITIONS_SHOWN)
  })
})
