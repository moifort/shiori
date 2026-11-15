import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { CoverUrl } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

let serves = true
mock.module('~/domain/book/infrastructure/published-cover', () => ({
  shelfCoverOf: async () => undefined,
  publishedCoverOf: async () => undefined,
  isCoverGone: async () => false,
  isImageAt: async () => serves,
  isbnCoversOf: async () => ({ amazon: 'https://m.media-amazon.com/images/I/p.jpg' }),
  otherEditionCoversOf: async () => [],
}))

const { ReleaseUseCase } = await import('~/domain/release/use-case')
const { ReleaseCommand } = await import('~/domain/release/command')
const { ReleaseQuery } = await import('~/domain/release/query')
const { releaseKeyOf } = await import('~/domain/release/business-rules')
const { BookUseCase } = await import('~/domain/book/use-case')
const { WishUseCase } = await import('~/domain/wish/use-case')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const bob = 'bob' as UserId
const alice = 'alice' as UserId
const picked = 'https://covers.example/piranesi-picked.jpg' as CoverUrl
const key = releaseKeyOf('Piranesi', 'Susanna Clarke', 'book', 'fr')

const release = () =>
  ReleaseCommand.saveWatch({
    key,
    title: BookTitle('Piranesi'),
    author: AuthorName('Susanna Clarke'),
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt: new Date('2026-11-01'),
    found: { isbn13: '9782355841058', coverUrl: 'https://covers.example/found.jpg' } as never,
  })

beforeEach(() => {
  resetFakeFirestore()
  serves = true
})

describe('a cover picked for a book nobody here holds', () => {
  test('is kept on its shared release, and logged with who picked it', async () => {
    await release()

    expect(await ReleaseUseCase.chooseCover(bob, key, picked)).toBe('chosen')

    expect((await ReleaseQuery.byKeys([key])).get(key)?.chosenCover?.url).toBe(picked)
    const log = (await fakeDb().collection('catalogue-corrections').get()).docs.map((doc) =>
      doc.data(),
    )
    expect(log).toMatchObject([
      { userId: bob, catalogue: 'release', documentId: key, field: 'cover', after: picked },
    ])
  })

  test('survives the next look on the web', async () => {
    await release()
    await ReleaseUseCase.chooseCover(bob, key, picked)

    await release()

    expect((await ReleaseQuery.byKeys([key])).get(key)?.chosenCover?.url).toBe(picked)
  })

  test('is refused when the address serves no image, and nothing is written', async () => {
    await release()
    serves = false

    expect(await ReleaseUseCase.chooseCover(bob, key, picked)).toBe('not-an-image')
    expect((await ReleaseQuery.byKeys([key])).get(key)?.chosenCover).toBeUndefined()
  })

  test('is refused for a release never described nor watched', async () => {
    expect(await ReleaseUseCase.chooseCover(bob, key, picked)).toBe('not-found')
  })

  test('is offered among the choices, the cover drawn first', async () => {
    await release()
    const drawn = 'https://covers.example/found.jpg' as CoverUrl

    const choices = await ReleaseUseCase.coverChoices(key, drawn)

    expect(choices).toEqual([
      { source: 'web', url: drawn, current: true },
      {
        source: 'amazon',
        url: 'https://m.media-amazon.com/images/I/p.jpg' as CoverUrl,
        current: false,
      },
    ])
  })

  test('is drawn on every reader’s wish for it', async () => {
    await release()
    await ReleaseUseCase.chooseCover(alice, key, picked)
    await WishUseCase.wish(
      bob,
      {
        title: BookTitle('Piranesi'),
        authors: [AuthorName('Susanna Clarke')],
        format: 'book',
        language: 'fr',
        coverUrl: 'https://covers.example/found.jpg' as CoverUrl,
      },
      { kind: 'discovery' },
    )

    const [wish] = await WishUseCase.wishes(bob, 'fr')

    expect(wish?.coverUrl).toBe(picked)
  })

  test('follows the book onto a reader’s shelf', async () => {
    await release()
    await ReleaseUseCase.chooseCover(alice, key, picked)

    const book = await BookUseCase.add(bob, {
      title: BookTitle('Piranesi'),
      authors: [AuthorName('Susanna Clarke')],
      language: 'fr',
      publishedCoverUrl: 'https://covers.example/found.jpg' as CoverUrl,
    })

    expect(book.chosenCover).toEqual({ source: 'url', url: picked })
  })
})
