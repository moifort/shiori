import { describe, expect, test } from 'bun:test'
import { Subgenre } from '~/domain/book/primitives'
import {
  favoritesOutsideSagas,
  friendPicksOf,
  friendSagaStateOf,
  inReadingOrder,
  isLovedByMany,
  lastActivityOf,
  lastFinishedOf,
  newestFavoritesFirst,
  picksPerFriend,
  recentHeartsOf,
  subgenreOf,
} from '~/domain/friendship/business-rules'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'

const day = (n: number) => new Date(Date.UTC(2026, 8, n))

describe('lastActivityOf', () => {
  // A listening position moved by the nightly sync is activity too, and it
  // only ever shows as `updatedAt`.
  test('takes the latest of every stamp the record carries', () => {
    expect(
      lastActivityOf({
        addedAt: day(1),
        startedAt: day(3),
        statusChangedAt: day(3),
        updatedAt: day(9),
      }),
    ).toEqual(day(9))
  })

  test('falls back to the day it was added on a record with no other stamp', () => {
    expect(lastActivityOf({ addedAt: day(2) })).toEqual(day(2))
  })
})

describe('friendSagaStateOf', () => {
  test('reads not started, complete or in progress off the volumes on the shelf', () => {
    expect(friendSagaStateOf([{ status: 'to-read' }, { status: 'to-read' }])).toBe('not-started')
    expect(friendSagaStateOf([{ status: 'read' }, { status: 'read' }])).toBe('complete')
    expect(friendSagaStateOf([{ status: 'read' }, { status: 'to-read' }])).toBe('in-progress')
    expect(friendSagaStateOf([{ status: 'reading' }])).toBe('in-progress')
  })
})

describe('lastFinishedOf', () => {
  test('picks the book read with the latest finishing date', () => {
    const books = [
      { title: 'earlier', status: 'read' as const, finishedAt: day(3) },
      { title: 'latest', status: 'read' as const, finishedAt: day(9) },
      { title: 'in progress', status: 'reading' as const },
    ]
    expect(lastFinishedOf(books)?.title).toBe('latest')
  })

  // A book filed as read with no date says nothing about when.
  test('answers nothing when no book read carries its date', () => {
    expect(lastFinishedOf([{ status: 'read' as const }, { status: 'to-read' as const }])).toBe(
      undefined,
    )
  })
})

describe('newestFavoritesFirst', () => {
  test('puts the most recently hearted first', () => {
    const favorites = [
      { title: 'old', addedAt: day(1), favoritedAt: day(2) },
      { title: 'new', addedAt: day(1), favoritedAt: day(8) },
    ]
    expect(newestFavoritesFirst(favorites).map(({ title }) => title)).toEqual(['new', 'old'])
  })

  // A heart given before the date was kept is older than any dated heart.
  test('ranks an undated heart on the book last activity, after a dated one', () => {
    const favorites = [
      { title: 'undated', addedAt: day(1), updatedAt: day(5) },
      { title: 'dated', addedAt: day(1), favoritedAt: day(9) },
      { title: 'older undated', addedAt: day(1), updatedAt: day(3) },
    ]
    expect(newestFavoritesFirst(favorites).map(({ title }) => title)).toEqual([
      'dated',
      'undated',
      'older undated',
    ])
  })
})

describe('favoritesOutsideSagas', () => {
  const dune = SeriesId('dune--frank-herbert')
  const inSaga = (title: string, id: typeof dune) => ({
    title,
    series: { id, name: SeriesName('Saga'), volume: VolumeNumber(1), kind: 'main' as const },
  })

  test('drops a volume already standing for through its hearted saga', () => {
    const favorites = [
      inSaga('Dune', dune),
      inSaga('Hypérion', SeriesId('hyperion--dan-simmons')),
      { title: 'Piranesi', series: undefined },
    ]

    expect(favoritesOutsideSagas(favorites, new Set([dune])).map((book) => book.title)).toEqual([
      'Hypérion',
      'Piranesi',
    ])
  })
})

describe('subgenreOf', () => {
  const tagged = (label: string) => ({ label: Subgenre(label), language: 'fr' as const })

  test('reads the subgenre off a volume of the saga genre', () => {
    const books = [
      { genre: 'fantasy' as const, subgenres: [tagged('Urban fantasy')] },
      { genre: 'science-fiction' as const, subgenres: [tagged('Space opera')] },
    ]

    expect(subgenreOf(books, 'science-fiction')?.label).toBe(Subgenre('Space opera'))
  })

  test('says nothing when no volume of that genre has a subgenre', () => {
    expect(subgenreOf([{ genre: 'fantasy' as const, subgenres: [] }], 'fantasy')).toBeUndefined()
  })
})

describe('inReadingOrder', () => {
  const volume = (title: string, number: number | undefined, kind: 'main' | 'novella') => ({
    title,
    series: {
      id: SeriesId('dune--frank-herbert'),
      name: SeriesName('Dune'),
      volume: number === undefined ? undefined : VolumeNumber(number),
      kind,
    },
  })

  test('puts main volumes first by number, the rest after, whatever order the shelf holds them in', () => {
    const volumes = [
      volume('Les Enfants de Dune', 3, 'main'),
      volume('Une nouvelle', 1, 'novella'),
      volume('Sans numéro', undefined, 'main'),
      volume('Dune', 1, 'main'),
    ]

    expect(inReadingOrder(volumes).map((book) => book.title)).toEqual([
      'Dune',
      'Les Enfants de Dune',
      'Sans numéro',
      'Une nouvelle',
    ])
  })
})

describe('recentHeartsOf', () => {
  const alice = 'alice' as UserId
  const bob = 'bob' as UserId
  const dune = SeriesId('dune')
  const saga = (id: typeof dune) => ({ id })
  const book = (title: string, favoritedAt?: Date, seriesId?: typeof dune) => ({
    title,
    favorite: true,
    favoritedAt,
    series: seriesId
      ? { id: seriesId, name: SeriesName('Dune'), volume: VolumeNumber(1), kind: 'main' as const }
      : undefined,
  })

  test("keeps each friend's last heart, saga or book, the newest first, up to the limit", () => {
    const hearts = recentHeartsOf(
      [
        {
          friendId: alice,
          books: [book('Hypérion', day(10)), book('Vagabond', day(20))],
          sagas: [],
          favoriteSagas: new Map(),
        },
        {
          friendId: bob,
          books: [],
          sagas: [saga(dune)],
          favoriteSagas: new Map([[dune, day(15)]]),
        },
      ],
      day(1),
      2,
    )

    expect(hearts.map((heart) => heart.book?.title ?? heart.saga?.id)).toEqual(['Vagabond', 'dune'])
    expect(hearts[1]?.friendId).toBe(bob)
  })

  // A friend who hearted a whole series in one evening is one tile, not ten.
  test('shows one heart per friend, the last one they gave', () => {
    const hearts = recentHeartsOf(
      [
        {
          friendId: alice,
          books: [book('Hypérion', day(10)), book('Vagabond', day(20))],
          sagas: [saga(dune)],
          favoriteSagas: new Map([[dune, day(15)]]),
        },
      ],
      day(1),
      10,
    )

    expect(hearts.map((heart) => heart.book?.title ?? heart.saga?.id)).toEqual(['Vagabond'])
  })

  // A heart given before the window, or before its date was kept, is not news.
  test('leaves out the hearts older than the window and the undated ones', () => {
    const hearts = recentHeartsOf(
      [
        {
          friendId: alice,
          books: [book('Old', day(2)), book('Undated'), book('New', day(9))],
          sagas: [saga(dune)],
          favoriteSagas: new Map([[dune, undefined]]),
        },
      ],
      day(5),
      10,
    )

    expect(hearts.map((heart) => heart.book?.title)).toEqual(['New'])
  })

  // The hearted saga stands for its volumes, as on the friend's profile; and a
  // saga held in two languages is one heart.
  test('names a hearted saga once and none of its volumes', () => {
    const hearts = recentHeartsOf(
      [
        {
          friendId: alice,
          books: [book('Dune', day(9), dune)],
          sagas: [saga(dune), saga(dune)],
          favoriteSagas: new Map([[dune, day(8)]]),
        },
      ],
      day(1),
      10,
    )

    expect(hearts).toEqual([{ friendId: alice, favoritedAt: day(8), saga: saga(dune) }])
  })
})

describe('isLovedByMany', () => {
  // One heart is a friend's taste, however few friends the reader has.
  test('needs two friends at least, then a third of them', () => {
    expect(isLovedByMany(1, 1)).toBe(false)
    expect(isLovedByMany(1, 2)).toBe(false)
    expect(isLovedByMany(2, 2)).toBe(true)
    expect(isLovedByMany(2, 6)).toBe(true)
    expect(isLovedByMany(3, 10)).toBe(false)
    expect(isLovedByMany(4, 10)).toBe(true)
    expect(isLovedByMany(9, 30)).toBe(false)
    expect(isLovedByMany(10, 30)).toBe(true)
  })
})

describe('friendPicksOf', () => {
  const alice = 'alice' as UserId
  const bob = 'bob' as UserId
  const carol = 'carol' as UserId
  const dune = SeriesId('dune--frank-herbert')
  const duneHeard = SeriesId('dune--frank-herbert--audio')
  const book = (
    title: string,
    author: string,
    options: { favoritedAt?: Date; favorite?: boolean; seriesId?: typeof dune } = {},
  ) => ({
    title: BookTitle(title),
    authors: [AuthorName(author)],
    favorite: options.favorite ?? true,
    favoritedAt: options.favoritedAt,
    addedAt: day(1),
    series: options.seriesId
      ? {
          id: options.seriesId,
          name: SeriesName('Dune'),
          volume: VolumeNumber(1),
          kind: 'main' as const,
        }
      : undefined,
  })
  const shelf = (
    friendId: UserId,
    books: ReturnType<typeof book>[],
    favoriteSagas: [typeof dune, Date | undefined][] = [],
  ) => ({
    friendId,
    books,
    sagas: favoriteSagas.map(([id]) => ({
      id,
      books: books.filter((entry) => entry.series?.id === id),
    })),
    favoriteSagas: new Map(favoriteSagas),
  })

  test('lists the hearted books the newest heart first, up to the limit', () => {
    const picks = friendPicksOf(
      [
        shelf(alice, [
          book('Hypérion', 'Dan Simmons', { favoritedAt: day(10) }),
          book('Vagabond', 'Inoue', { favoritedAt: day(20) }),
          book('Not hearted', 'Nobody', { favorite: false }),
        ]),
        shelf(bob, [book('Fondation', 'Asimov', { favoritedAt: day(15) })]),
      ],
      [],
      2,
    )

    expect(picks.books.map((pick) => String(pick.item.title))).toEqual(['Vagabond', 'Fondation'])
    expect(picks.books[1]?.friendId).toBe(bob)
  })

  // The story counts, not the format: the reader holding it heard need not
  // be told a friend loved it on paper.
  test('leaves out the stories, sagas and authors the reader holds in any format', () => {
    const picks = friendPicksOf(
      [
        shelf(
          alice,
          [
            book('Hypérion', 'Dan Simmons', { favoritedAt: day(10) }),
            book('Dune', 'Frank Herbert', { favoritedAt: day(12), seriesId: dune }),
          ],
          [[dune, day(12)]],
        ),
      ],
      [
        { title: BookTitle('Hyperion'), authors: [AuthorName('Dan Simmons')] },
        {
          title: BookTitle('Le Messie de Dune'),
          authors: [AuthorName('Frank Herbert')],
          series: {
            id: duneHeard,
            name: SeriesName('Dune'),
            volume: VolumeNumber(2),
            kind: 'main',
          },
        },
      ],
      10,
    )

    // The first volume is a story of its own the reader lacks.
    expect(picks.books.map((pick) => String(pick.item.title))).toEqual(['Dune'])
    expect(picks.sagas).toEqual([])
    expect(picks.authors).toEqual([])
  })

  test('folds a thing several friends love, the copy hearted last standing for it', () => {
    const picks = friendPicksOf(
      [
        shelf(alice, [book('Hypérion', 'Dan Simmons', { favoritedAt: day(10) })]),
        shelf(bob, [book('Hyperion', 'Dan Simmons', { favoritedAt: day(18) })]),
        shelf(carol, []),
      ],
      [],
      10,
    )

    expect(picks.books).toHaveLength(1)
    expect(picks.books[0]?.friendId).toBe(bob)
    expect(picks.books[0]?.friendIds).toEqual([bob, alice])
    expect(picks.books[0]?.lovedByMany).toBe(true)
    expect(picks.authors.map((pick) => [String(pick.item.name), pick.friendIds])).toEqual([
      ['Dan Simmons', [bob, alice]],
    ])
  })

  // A saga read by one friend and heard by another is one story.
  test('folds a saga hearted read and heard into one, and names its authors', () => {
    const picks = friendPicksOf(
      [
        shelf(
          alice,
          [book('Dune', 'Frank Herbert', { favorite: false, seriesId: dune })],
          [[dune, day(5)]],
        ),
        shelf(
          bob,
          [book('Dune', 'Frank Herbert', { favorite: false, seriesId: duneHeard })],
          [[duneHeard, day(7)]],
        ),
        shelf(carol, []),
        shelf('dave' as UserId, []),
        shelf('erin' as UserId, []),
        shelf('fred' as UserId, []),
        shelf('gus' as UserId, []),
      ],
      [],
      10,
    )

    expect(picks.sagas.map((pick) => [pick.item.id, pick.friendIds])).toEqual([
      [duneHeard, [bob, alice]],
    ])
    expect(picks.sagas[0]?.lovedByMany).toBe(false)
    expect(picks.books).toEqual([])
    expect(picks.authors.map((pick) => String(pick.item.name))).toEqual(['Frank Herbert'])
  })

  test('shows two picks per friend at most, so one busy friend does not fill the shelf', () => {
    const picks = friendPicksOf(
      [
        shelf(alice, [
          book('One', 'A', { favoritedAt: day(30) }),
          book('Two', 'B', { favoritedAt: day(29) }),
          book('Three', 'C', { favoritedAt: day(28) }),
        ]),
        shelf(bob, [book('Four', 'D', { favoritedAt: day(10) })]),
      ],
      [],
      10,
    )

    expect(picks.books.map((pick) => String(pick.item.title))).toEqual(['One', 'Two', 'Four'])
    expect(picks.authors.map((pick) => String(pick.item.name))).toEqual(['A', 'B', 'D'])
  })

  test('shows one pick per friend past five friends', () => {
    const friends = ['alice', 'bob', 'carol', 'dave', 'erin', 'fred'] as UserId[]
    const picks = friendPicksOf(
      friends.map((friendId, index) =>
        shelf(friendId, [
          book(`${friendId} new`, `${friendId} A`, { favoritedAt: day(40 - index) }),
          book(`${friendId} old`, `${friendId} B`, { favoritedAt: day(20 - index) }),
        ]),
      ),
      [],
      20,
    )

    expect(picks.books.map((pick) => String(pick.item.title))).toEqual(
      friends.map((friendId) => `${friendId} new`),
    )
  })

  test('picksPerFriend', () => {
    expect(picksPerFriend(1)).toBe(2)
    expect(picksPerFriend(5)).toBe(2)
    expect(picksPerFriend(6)).toBe(1)
  })

  test('ranks an undated heart on the last activity of what it is on', () => {
    const picks = friendPicksOf(
      [
        shelf(alice, [
          book('Undated', 'Nobody'),
          book('Dated', 'Somebody', { favoritedAt: day(3) }),
        ]),
      ],
      [],
      10,
    )

    expect(picks.books.map((pick) => String(pick.item.title))).toEqual(['Dated', 'Undated'])
  })
})
