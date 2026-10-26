import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { CoverUrl, Isbn13 } from '~/domain/book/primitives'
import {
  isbnsInLanguage,
  isCoverGone,
  isImageAt,
  publishedCoverOf,
  shelfCoverOf,
} from '~/domain/scan/published-cover'

const isbn = Isbn13('9782070612758')
/** A 979 ISBN has no ISBN-10, so Amazon cannot be asked for it at all. */
const isbn979 = Isbn13('9791030703184')

/** Answers Amazon, Open Library and ePagine each their own way, recording which
 *  was asked. ePagine answers its PNG stand-in unless told it has the cover. */
const sourcesAnswer = ({
  amazon,
  openLibrary,
  epagine = 'image/png',
}: {
  amazon: string
  openLibrary: number
  epagine?: string
}) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    if (url.includes('openlibrary.org')) {
      asked.push('open-library')
      return new Response(null, { status: openLibrary })
    }
    if (url.includes('epagine.fr')) {
      asked.push('epagine')
      return new Response(null, { status: 200, headers: { 'content-type': epagine } })
    }
    asked.push('amazon')
    return new Response(null, { status: 200, headers: { 'content-type': amazon } })
  }) as unknown as typeof fetch)
  return asked
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('publishedCoverOf', () => {
  test('keeps Amazon and never asks Open Library when it has the cover', async () => {
    const asked = sourcesAnswer({ amazon: 'image/jpeg', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('m.media-amazon.com')
    expect(asked).toEqual(['amazon'])
  })

  test('falls back to Open Library when Amazon answers its placeholder', async () => {
    const asked = sourcesAnswer({ amazon: 'image/gif', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('covers.openlibrary.org')
    expect(asked).toEqual(['amazon', 'open-library'])
  })

  test('goes straight to Open Library for a 979 ISBN, which Amazon cannot file', async () => {
    const asked = sourcesAnswer({ amazon: 'image/jpeg', openLibrary: 302 })

    const cover = await publishedCoverOf(isbn979)

    expect(String(cover)).toContain('covers.openlibrary.org')
    expect(asked).toEqual(['open-library'])
  })

  test('falls back to ePagine for a French edition the other two miss', async () => {
    const asked = sourcesAnswer({ amazon: 'image/gif', openLibrary: 404, epagine: 'image/jpeg' })

    const cover = await publishedCoverOf(isbn)

    expect(String(cover)).toContain('images.epagine.fr')
    expect(asked).toEqual(['amazon', 'open-library', 'epagine'])
  })

  test('has no cover when no source has one', async () => {
    sourcesAnswer({ amazon: 'image/gif', openLibrary: 404 })
    expect(await publishedCoverOf(isbn)).toBeUndefined()
  })
})

/** Answers every probe with one response, or fails it when given an Error. */
const coverAnswers = (answer: Response | Error) =>
  spyOn(globalThis, 'fetch').mockImplementation((async () => {
    if (answer instanceof Error) throw answer
    return answer
  }) as unknown as typeof fetch)

const stored = CoverUrl('https://m.media-amazon.com/images/P/2070612759.01._SCLZZZZZZZ_.jpg')

describe('isCoverGone', () => {
  test('is gone when the source answers 404', async () => {
    coverAnswers(new Response(null, { status: 404 }))
    expect(await isCoverGone(stored)).toBe(true)
  })

  test('is gone when the source answers its blank stand-in', async () => {
    coverAnswers(
      new Response(null, {
        status: 200,
        headers: { 'content-type': 'image/gif', 'content-length': '43' },
      }),
    )
    expect(await isCoverGone(stored)).toBe(true)
  })

  test('still loads when the source answers an image', async () => {
    coverAnswers(
      new Response(null, {
        status: 200,
        headers: { 'content-type': 'image/jpeg', 'content-length': '21504' },
      }),
    )
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('still loads when Open Library redirects to its mirror', async () => {
    coverAnswers(new Response(null, { status: 302 }))
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('is kept when the source cannot be reached', async () => {
    coverAnswers(new Error('The operation was aborted due to timeout'))
    expect(await isCoverGone(stored)).toBe(false)
  })

  test('is kept when the source answers an error of its own', async () => {
    coverAnswers(new Response(null, { status: 503 }))
    expect(await isCoverGone(stored)).toBe(false)
  })
})

describe('isbnsInLanguage', () => {
  // Le Petit Prince: an English, a French and a Japanese edition, and an ISBN-10.
  const work = ['9780156012195', '9782070612758', '9784001156768', '2070612759', '9791030703184']

  test('keeps the editions published in the language, in their order', () => {
    expect(isbnsInLanguage(work, 'fr').map(String)).toEqual(['9782070612758', '9791030703184'])
    expect(isbnsInLanguage(work, 'en').map(String)).toEqual(['9780156012195'])
  })

  test('keeps nothing for a language with no group to trust', () => {
    expect(isbnsInLanguage(work, 'ko')).toEqual([])
  })

  test('drops an ISBN whose check digit does not match', () => {
    expect(isbnsInLanguage(['9782070612750'], 'fr')).toEqual([])
  })
})

/** Answers Open Library's search with these ISBNs, and each cover source by
 *  whether the ISBN asked is one that has a cover. */
const shelfAnswers = (search: string[][], covered: string[]) => {
  const searches: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    if (url.includes('search.json')) {
      searches.push(url)
      const isbn = search[searches.length - 1] ?? []
      return Response.json({ docs: isbn.length > 0 ? [{ isbn }] : [] })
    }
    const has = covered.some((isbn) => url.includes(isbn))
    if (url.includes('openlibrary.org')) return new Response(null, { status: has ? 302 : 404 })
    return new Response(null, {
      status: 200,
      headers: { 'content-type': has ? 'image/jpeg' : 'image/gif' },
    })
  }) as unknown as typeof fetch)
  return searches
}

describe('shelfCoverOf', () => {
  const onePiece = {
    title: 'One Piece',
    author: 'Eiichiro Oda',
    volume: 5,
    language: 'fr' as const,
  }

  test('takes the cover of the first edition in the language that has one', async () => {
    // The Japanese original comes first and must be skipped; the first French
    // edition has no cover, the second does.
    shelfAnswers([['9784088725093', '9782723433358', '9782723434829']], ['2723434826'])

    const cover = await shelfCoverOf(onePiece)

    expect(String(cover)).toContain('2723434826')
  })

  test('searches with the volume number, then broadly when that finds nothing', async () => {
    const searches = shelfAnswers([[], ['9782723434829']], ['2723434826'])

    const cover = await shelfCoverOf(onePiece)

    expect(cover).toBeDefined()
    expect(new URL(searches[0]).searchParams.get('title')).toBe('One Piece 5')
    expect(new URL(searches[1]).searchParams.get('q')).toBe(
      'title:(One Piece 5) author:(Eiichiro Oda)',
    )
  })

  test('has no cover when the work has no edition in the language', async () => {
    shelfAnswers([['9781421539898']], ['1421539896'])
    expect(await shelfCoverOf(onePiece)).toBeUndefined()
  })

  test('has no cover when Open Library cannot be reached', async () => {
    coverAnswers(new Error('The operation was aborted due to timeout'))
    expect(await shelfCoverOf(onePiece)).toBeUndefined()
  })
})

describe('isImageAt', () => {
  const pasted = CoverUrl('https://www.shoparize.com/fr/p/dernier-combat/9791028110116')

  test('takes an address that serves an image', async () => {
    coverAnswers(
      new Response(null, { headers: { 'content-type': 'image/jpeg', 'content-length': '250000' } }),
    )
    expect(await isImageAt(pasted)).toBe(true)
  })

  test('refuses a web page', async () => {
    coverAnswers(new Response(null, { headers: { 'content-type': 'text/html' } }))
    expect(await isImageAt(pasted)).toBe(false)
  })

  test('asks again with GET a server that refuses HEAD', async () => {
    const methods: string[] = []
    spyOn(globalThis, 'fetch').mockImplementation((async (_url: string, init?: RequestInit) => {
      methods.push(init?.method ?? 'GET')
      return init?.method === 'HEAD'
        ? new Response(null, { status: 405 })
        : new Response(null, { headers: { 'content-type': 'image/png' } })
    }) as unknown as typeof fetch)

    expect(await isImageAt(pasted)).toBe(true)
    expect(methods).toEqual(['HEAD', 'GET'])
  })

  test('takes an address behind a bot wall, which the phone loads', async () => {
    coverAnswers(new Response('<html>Just a moment…</html>', { status: 403 }))
    expect(await isImageAt(pasted)).toBe(true)
  })

  test('refuses an address that is gone', async () => {
    coverAnswers(new Response('<html>Not found</html>', { status: 404 }))
    expect(await isImageAt(pasted)).toBe(false)
  })

  test('refuses an address that cannot be reached', async () => {
    coverAnswers(new Error('The operation timed out.'))
    expect(await isImageAt(pasted)).toBe(false)
  })
})
