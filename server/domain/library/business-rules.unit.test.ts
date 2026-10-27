import { describe, expect, test } from 'bun:test'
import type { AwardedWork } from '~/domain/award/types'
import { BookId, NarratorName, StarRating } from '~/domain/book/primitives'
import type { Book, BookFormat, ReadingStatus } from '~/domain/book/types'
import { PILE_SECTION_LIMIT, pileFormatsOf, pileSectionsOf } from '~/domain/library/business-rules'
import type { PileSectionKind } from '~/domain/library/types'
import { narratorKeyOf } from '~/domain/narrator/primitives'
import { SagaKey, SeriesName, seriesIdOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle, PersonName, UserId } from '~/domain/shared/primitives'

const NOW = new Date('2026-10-27T10:00:00.000Z')
const daysAgo = (days: number) => new Date(NOW.getTime() - days * 86_400_000)

type Spec = {
  title: string
  status?: ReadingStatus
  author?: string
  narrator?: string
  format?: BookFormat
  rating?: number
  favorite?: boolean
  saga?: string
  volume?: number
  recommender?: string
  days?: number
}

const book = (spec: Spec): Book => ({
  id: BookId(spec.title),
  userId: UserId('reader'),
  title: BookTitle(spec.title),
  authors: spec.author ? [AuthorName(spec.author)] : [],
  format: spec.format ?? 'book',
  media: ['print'],
  subgenres: [],
  narrators: spec.narrator ? [NarratorName(spec.narrator)] : [],
  status: spec.status ?? 'to-read',
  hidden: false,
  addedAt: daysAgo(spec.days ?? 0),
  startedAt: spec.status === 'reading' ? daysAgo(spec.days ?? 0) : undefined,
  finishedAt: spec.status === 'read' ? daysAgo(spec.days ?? 0) : undefined,
  rating: spec.rating === undefined ? undefined : StarRating(spec.rating),
  favorite: spec.favorite,
  recommendation: spec.recommender ? { recommenderName: PersonName(spec.recommender) } : undefined,
  series: spec.saga
    ? {
        id: seriesIdOf(SagaKey(spec.saga), undefined),
        saga: SagaKey(spec.saga),
        name: SeriesName(spec.saga),
        volume: spec.volume === undefined ? undefined : VolumeNumber(spec.volume),
        kind: 'main',
      }
    : undefined,
})

const work = (title: string, author: string, year: number): AwardedWork => ({
  key: `${title}--${author}`,
  title: BookTitle(title),
  authors: [AuthorName(author)],
  language: 'en',
  mentions: [{ award: 'hugo', year }],
})

const section = (books: Book[], kind: PileSectionKind, works: AwardedWork[] = []) =>
  pileSectionsOf(books, works, {})
    .find((s) => s.kind === kind)
    ?.picks.map((pick) => String(pick.book.title))

describe('the pile sections', () => {
  test('offers the books in progress, the one begun longest ago first', () => {
    const books = [
      book({ title: 'Récent', status: 'reading', days: 6 }),
      book({ title: 'Ancien', status: 'reading', days: 240 }),
      book({ title: 'Pile', days: 3 }),
    ]
    expect(section(books, 'to-finish')).toEqual(['Ancien', 'Récent'])
  })

  test('offers the first unread volume of each saga begun, the saga read last first', () => {
    const books = [
      book({ title: 'Red Rising 5', status: 'read', saga: 'red-rising', volume: 5, days: 30 }),
      book({ title: 'Red Rising 7', saga: 'red-rising', volume: 7 }),
      book({ title: 'Red Rising 6', saga: 'red-rising', volume: 6 }),
      book({ title: 'Frieren 12', status: 'read', saga: 'frieren', volume: 12, days: 2 }),
      book({ title: 'Frieren 13', saga: 'frieren', volume: 13 }),
      book({ title: 'Silo 1', saga: 'silo', volume: 1 }),
    ]
    expect(section(books, 'next-volume')).toEqual(['Frieren 13', 'Red Rising 6'])
  })

  test('offers what someone recommended', () => {
    const books = [book({ title: 'Piranesi', recommender: 'Julie' }), book({ title: 'Dune' })]
    expect(section(books, 'recommended')).toEqual(['Piranesi'])
  })

  test('offers the authors rated four stars or more, or hearted', () => {
    const books = [
      book({ title: 'Mistborn', status: 'read', author: 'Brandon Sanderson', rating: 4 }),
      book({ title: 'Ubik', status: 'read', author: 'Philip K. Dick', rating: 3, favorite: true }),
      book({ title: 'Pas fan', status: 'read', author: 'Quelqu’un', rating: 3 }),
      book({ title: 'Elantris', author: 'Brandon Sanderson' }),
      book({ title: 'Substance mort', author: 'Philip K. Dick' }),
      book({ title: 'Autre', author: 'Quelqu’un' }),
    ]
    expect(section(books, 'favorite-authors')).toEqual(['Elantris', 'Substance mort'])
  })

  test('offers the recordings read by a narrator the reader hearted, not one they rated', () => {
    const books = [
      book({
        title: 'Leviathan',
        status: 'read',
        format: 'audiobook',
        narrator: 'Jefferson Mays',
        rating: 5,
      }),
      book({ title: 'Caliban', format: 'audiobook', narrator: 'Jefferson Mays' }),
      book({ title: 'Silo', format: 'audiobook', narrator: 'Tim Gerard Reynolds' }),
    ]
    const hearted = new Set([narratorKeyOf(NarratorName('Tim Gerard Reynolds'))])

    expect(
      pileSectionsOf(books, [], {}, hearted)
        .find((s) => s.kind === 'favorite-narrators')
        ?.picks.map((pick) => String(pick.book.title)),
    ).toEqual(['Silo'])
    expect(section(books, 'favorite-narrators')).toBeUndefined()
  })

  test('finds the award winners, a translation keeping its title included, with the prize', () => {
    const books = [
      book({ title: 'Hypérion', author: 'Dan Simmons' }),
      book({ title: 'La Main gauche de la nuit', author: 'Ursula K. Le Guin' }),
    ]
    const works = [
      work('Hyperion', 'Dan Simmons', 1990),
      work('The Left Hand of Darkness', 'Ursula K. Le Guin', 1970),
    ]
    const awarded = pileSectionsOf(books, works, {}).find((s) => s.kind === 'awarded')
    expect(awarded?.picks.map((pick) => [String(pick.book.title), pick.award])).toEqual([
      ['Hypérion', { award: 'hugo', year: 1990 }],
    ])
  })

  test('offers the authors read nothing of yet, never a book naming none', () => {
    const books = [
      book({ title: 'Fondation', status: 'read', author: 'Isaac Asimov' }),
      book({ title: 'Les Robots', author: 'Isaac Asimov' }),
      book({ title: 'Dune', author: 'Frank Herbert' }),
      book({ title: 'Anonyme' }),
    ]
    expect(section(books, 'new-authors')).toEqual(['Dune'])
  })

  test('leaves an empty section out and keeps the order of the screen', () => {
    const books = [
      book({ title: 'En cours', status: 'reading', author: 'A' }),
      book({ title: 'Conseillé', recommender: 'Marc', author: 'B' }),
    ]
    expect(pileSectionsOf(books, [], {}).map((s) => s.kind)).toEqual([
      'to-finish',
      'recommended',
      'new-authors',
    ])
  })

  test('cuts a section to a rail', () => {
    const books = Array.from({ length: PILE_SECTION_LIMIT + 5 }, (_, i) =>
      book({ title: `Livre ${i}`, author: `Auteur ${i}`, days: i }),
    )
    expect(section(books, 'new-authors')).toHaveLength(PILE_SECTION_LIMIT)
  })

  test('narrows what is offered to the view, never the history it is judged by', () => {
    const books = [
      book({
        title: 'Leviathan',
        status: 'read',
        format: 'audiobook',
        author: 'James Corey',
        rating: 5,
      }),
      book({ title: 'Caliban', author: 'James Corey' }),
      book({ title: 'Frieren', format: 'manga', author: 'Kanehito Yamada' }),
    ]
    const sections = pileSectionsOf(books, [], { format: 'book' })
    const titles = sections.flatMap((s) => s.picks.map((pick) => String(pick.book.title)))
    expect(titles).toEqual(['Caliban'])
    expect(sections.map((s) => s.kind)).toEqual(['favorite-authors'])
  })

  test('offers the format pills of the pile and the books in progress only', () => {
    const books = [
      book({ title: 'Dune' }),
      book({ title: 'Frieren', format: 'manga', status: 'reading' }),
      book({ title: 'Leviathan', format: 'audiobook', status: 'read' }),
    ]
    expect(pileFormatsOf(books, { format: 'manga' })).toEqual(['book', 'manga'])
  })
})
