import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { openLibraryPortraitOf } from '~/domain/author/infrastructure/open-library'
import { AuthorName } from '~/domain/shared/primitives'

type Doc = { key: string; name: string; work_count?: number }

/** Answers the author search with `docs`, and the photo probe with `photo`
 *  (an Error fails the search). Records the photos asked for. */
const openLibraryAnswers = (docs: Doc[] | Error, photo = 200) => {
  const probed: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    if (url.includes('search/authors.json')) {
      if (docs instanceof Error) throw docs
      return Response.json({ docs })
    }
    probed.push(url)
    return new Response(null, { status: photo })
  }) as unknown as typeof fetch)
  return probed
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

const sanderson = AuthorName('Brandon Sanderson')

describe('openLibraryPortraitOf', () => {
  test('asks for the photo of the namesake with the most works', async () => {
    const probed = openLibraryAnswers([
      { key: 'OL16029248A', name: 'Brandon Sanderson', work_count: 14 },
      { key: 'OL1394865A', name: 'Brandon Sanderson', work_count: 206 },
    ])

    const portrait = await openLibraryPortraitOf(sanderson)

    expect(String(portrait)).toBe(
      'https://covers.openlibrary.org/a/olid/OL1394865A-M.jpg?default=false',
    )
    expect(probed).toHaveLength(1)
  })

  test('takes no one whose name is not the author’s', async () => {
    const probed = openLibraryAnswers([{ key: 'OL1A', name: 'Brandon Mull', work_count: 90 }])

    expect(await openLibraryPortraitOf(sanderson)).toBeUndefined()
    expect(probed).toEqual([])
  })

  test('has no portrait when Open Library has no photo of the author', async () => {
    openLibraryAnswers([{ key: 'OL3135944A', name: 'Brandon Sanderson' }], 404)
    expect(await openLibraryPortraitOf(sanderson)).toBeUndefined()
  })

  test('has no portrait when Open Library cannot be reached', async () => {
    openLibraryAnswers(new Error('The operation was aborted due to timeout'))
    expect(await openLibraryPortraitOf(sanderson)).toBeUndefined()
  })
})
