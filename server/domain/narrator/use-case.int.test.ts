import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { NarratorUseCase } = await import('~/domain/narrator/use-case')
const { NarratorCommand } = await import('~/domain/narrator/command')
const { narratorKeyOf } = await import('~/domain/narrator/primitives')
const { BookCommand } = await import('~/domain/book/command')
const { NarratorName } = await import('~/domain/book/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

/** One recording per narrator, read. */
const writeRecordings = async (narrators: string[]) => {
  for (const narrator of narrators)
    await BookCommand.add(reader, {
      title: BookTitle(`Heard by ${narrator}`),
      authors: [AuthorName('Somebody')],
      format: 'audiobook',
      narrators: [NarratorName(narrator)],
      status: 'read',
    })
}

describe('a page of the narrators list', () => {
  test('lists only the narrators the reader hearted under Préférés', async () => {
    await writeRecordings(['Ray Porter', 'Kate Reading', 'Michael Kramer'])
    await NarratorCommand.setFavorite(reader, narratorKeyOf('Kate Reading'), true)

    const { items, hasMore } = await NarratorUseCase.followedPage(reader, { limit: 10 }, 'loved')

    expect(items.map((narrator) => String(narrator.name))).toEqual(['Kate Reading'])
    expect(items[0]?.favorite).toBe(true)
    expect(hasMore).toBe(false)
  })

  test('lists nobody under Préférés before the reader hearts a narrator', async () => {
    await writeRecordings(['Ray Porter'])

    const { items } = await NarratorUseCase.followedPage(reader, { limit: 10 }, 'loved')

    expect(items).toEqual([])
  })

  test('lists every narrator by name', async () => {
    await writeRecordings(['Ray Porter', 'Kate Reading'])
    await NarratorCommand.setFavorite(reader, narratorKeyOf('Kate Reading'), true)

    const { items } = await NarratorUseCase.followedPage(reader, { limit: 10 }, 'name')

    expect(items.map((narrator) => String(narrator.name))).toEqual(['Ray Porter', 'Kate Reading'])
  })
})
