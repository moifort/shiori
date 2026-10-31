import { describe, expect, test } from 'bun:test'
import type { SharedActivity, SharedShelfToday } from '~/domain/analytics/types'
import type { Discovery } from '~/domain/discovery/types'
import type { Friend } from '~/domain/friendship/types'
import { feedEventsOf, feedPageOf, upcomingOf } from '~/domain/news/business-rules'
import type { UserId } from '~/domain/shared/types'

const activity = (
  kind: SharedActivity['kind'],
  title: string,
  at: string,
  rating?: number,
): SharedActivity =>
  ({
    kind,
    at: new Date(at),
    book: { id: `id-${title}`, title, authors: ['Auteur'], format: 'book' },
    ...(rating ? { rating } : {}),
  }) as unknown as SharedActivity

const friend = (id: string, recentActivity: SharedActivity[]): Friend => ({
  userId: id as UserId,
  firstName: id,
  since: new Date('2026-01-01'),
  shelf: { recentActivity } as unknown as SharedShelfToday,
})

describe('feedEventsOf', () => {
  const friends = [
    friend('marc', [
      activity('hearted', 'Arabe', '2026-10-30T09:00:00Z', 5),
      activity('added', 'Bruit', '2026-10-30T10:00:00Z'),
      activity('reading', 'Vagabond', '2026-10-29T10:00:00Z'),
    ]),
    friend('sophie', [activity('reading', 'Vagabond', '2026-10-30T08:00:00Z')]),
    friend('lea', [activity('reading', 'Vagabond', '2026-10-28T08:00:00Z')]),
  ]

  test('merges the friends newest first and leaves out shelving and dropping', () => {
    const events = feedEventsOf(friends, new Set())
    expect(events.map((event) => event.id)).toEqual([
      'marc~loved~id-Arabe',
      'sophie~started~id-Vagabond',
      'marc~started~id-Vagabond',
      'lea~started~id-Vagabond',
    ])
  })

  test('carries the stars and counts the other friends who started the same story', () => {
    const events = feedEventsOf(friends, new Set())
    expect(events[0]?.rating).toBe(5 as never)
    expect(events[1]?.alsoStartedBy).toBe(2)
    expect(events[0]?.alsoStartedBy).toBe(0)
  })

  test('tells a finish the friend also hearted once, as the heart', () => {
    const events = feedEventsOf(
      [
        friend('marc', [
          activity('read', 'Arabe', '2026-10-30T09:00:00Z', 5),
          activity('hearted', 'Arabe', '2026-10-30T09:00:00Z', 5),
        ]),
      ],
      new Set(),
    )
    expect(events.map((event) => event.kind)).toEqual(['loved'])
  })

  test('marks the stories the reader holds', () => {
    const events = feedEventsOf(friends, new Set(['arabe--auteur']))
    expect(events[0]?.inLibrary).toBe(true)
    expect(events[1]?.inLibrary).toBe(false)
  })
})

describe('feedPageOf', () => {
  const events = feedEventsOf(
    [
      friend('a', [
        activity('reading', 'One', '2026-10-30T10:00:00Z'),
        activity('read', 'Two', '2026-10-30T09:00:00Z'),
        activity('hearted', 'Three', '2026-10-30T08:00:00Z'),
      ]),
    ],
    new Set(),
  )

  test('pages with a cursor and ends without one', () => {
    const first = feedPageOf(events, 2)
    expect(first.events).toHaveLength(2)
    expect(first.nextCursor).toBeDefined()
    const second = feedPageOf(events, 2, first.nextCursor)
    expect(second.events.map((event) => event.kind)).toEqual(['loved'])
    expect(second.nextCursor).toBeUndefined()
  })

  test('restarts from the top on a cursor it cannot read', () => {
    expect(feedPageOf(events, 5, 'nonsense').events).toHaveLength(3)
  })
})

describe('upcomingOf', () => {
  const discovery = {
    sagas: [
      {
        series: {
          saga: 'red-rising',
          name: 'Red Rising',
          author: 'Pierce Brown',
          books: [{ format: 'book' }],
          opinion: { rating: 5, favorite: true },
        },
        next: { number: 6, title: 'Light Bringer', date: '2026-12-18' },
        missing: [],
        recent: [],
        watched: true,
      },
    ],
    authors: [
      {
        author: { key: 'andy-weir', name: 'Andy Weir', favorite: false, books: [] },
        next: { title: 'Nouveau roman' },
        recent: [],
        sagas: [],
        awaited: [
          {
            id: 'a1',
            state: 'announced',
            source: { title: 'Les Portes de pierre', authors: ['Patrick Rothfuss'] },
            found: { title: 'Les Portes de pierre' },
          },
          { id: 'a2', state: 'unannounced', source: { title: 'Rien', authors: [] } },
        ],
      },
    ],
    unwatched: 0,
    followed: 2,
  } as unknown as Discovery

  test('merges the follows, the soonest first and the undated last', () => {
    const releases = upcomingOf([{ format: 'book', discovery }])
    expect(releases.map((release) => String(release.title))).toEqual([
      'Light Bringer',
      'Nouveau roman',
      'Les Portes de pierre',
    ])
    expect(releases[0]?.sagaFavorite).toBe(true)
    expect(releases[0]?.date).toBe('2026-12-18' as never)
    expect(releases[1]?.date).toBeUndefined()
  })

  test('draws a recording in the audiobook format and lists a story once', () => {
    const releases = upcomingOf([
      { format: 'book', discovery },
      { format: 'audiobook', discovery },
    ])
    expect(releases.filter((release) => String(release.title) === 'Light Bringer')).toHaveLength(2)
    expect(releases.map((release) => release.format)).toContain('audiobook')
  })
})
