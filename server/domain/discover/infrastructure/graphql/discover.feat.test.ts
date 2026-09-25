import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')
const { BookUseCase } = await import('~/domain/book/use-case')
const { SeriesCommand } = await import('~/domain/series/command')
const { ReleaseDate, SeriesName, VolumeNumber, seriesKeyOf } = await import(
  '~/domain/series/primitives'
)
const { AuthorName, BookTitle, Year } = await import('~/domain/shared/primitives')

const bob = 'bob' as UserId
const run = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId: bob }, variableValues })
const inFrench = (source: string) =>
  graphql({
    schema,
    source,
    contextValue: {
      event: { node: { req: { headers: { 'accept-language': 'fr' } } } },
      userId: bob,
    },
  })

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('the Découvrir tab', () => {
  test('starts unprepared and empty', async () => {
    const result = await run(
      '{ discover { preparedAt canRefresh upcoming { key } maybe { key title editions { format date audibleUrl } } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.discover).toEqual({
      preparedAt: null,
      canRefresh: true,
      upcoming: [],
      maybe: [],
    })
  })

  test('dismisses nothing before the tab was ever opened', async () => {
    const result = await run('mutation { dismissRelease(key: "book--a--b") }')

    expect(result.data?.dismissRelease).toBe(false)
  })

  test('remembers a work the reader is not interested in', async () => {
    await run('{ discover { canRefresh } }')

    const result = await run('mutation { dismissRelease(key: "book--a--b") }')

    expect(result.data?.dismissRelease).toBe(true)
  })
})

describe('a saga’s release', () => {
  test('comes with the Series tab’s row in its language, its catalogue dated', async () => {
    const id = seriesKeyOf('System Universe', 'Dakota Krout', 'book')
    for (const volume of [1, 2])
      await BookUseCase.add(bob, {
        title: BookTitle(`System ${volume}`),
        authors: [AuthorName('Dakota Krout')],
        status: 'read',
        language: 'en',
        series: {
          id,
          name: SeriesName('System Universe'),
          volume: VolumeNumber(volume),
          kind: 'main',
        },
      })
    await SeriesCommand.catalogue({
      id,
      name: SeriesName('System Universe'),
      author: AuthorName('Dakota Krout'),
      catalogedAt: new Date('2026-01-01'),
      volumes: [1, 2, 3].map((volume) => ({
        number: VolumeNumber(volume),
        title: BookTitle(`System ${volume}`),
        kind: 'main' as const,
        publishedIn: Year(2020),
        releases: volume === 3 ? { fr: ReleaseDate('2099-10-08') } : undefined,
      })),
    })
    fake.seed('release-watches', `series--${id}--fr`, {
      key: `series--${id}--fr`,
      kind: 'series',
      title: 'System Universe',
      language: 'fr',
      checkedAt: new Date(),
      localTitle: 'Système Univers',
      editions: [{ title: 'Système 3', volume: 3, format: 'book', date: '2099-10-08' }],
    })

    const result = await inFrench(`{
      discover {
        upcoming {
          kind language readIn title nextDate seriesId
          editions { title volume date }
          series { name language ownedCount state catalogue { spine { number releases { language date } } } }
        }
      }
    }`)

    expect(result.errors).toBeUndefined()
    expect(result.data?.discover).toEqual({
      upcoming: [
        {
          kind: 'SERIES',
          language: 'FR',
          readIn: 'EN',
          title: 'Système Univers',
          nextDate: '2099-10-08',
          seriesId: id,
          editions: [{ title: 'Système 3', volume: 3, date: '2099-10-08' }],
          series: {
            name: 'Système Univers',
            language: 'FR',
            ownedCount: 0,
            state: null,
            catalogue: {
              spine: [
                { number: 1, releases: [] },
                { number: 2, releases: [] },
                { number: 3, releases: [{ language: 'FR', date: '2099-10-08' }] },
              ],
            },
          },
        },
      ],
    })
  })
})
