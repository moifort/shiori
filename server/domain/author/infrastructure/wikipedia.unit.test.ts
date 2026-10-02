import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import { AuthorName } from '~/domain/shared/primitives'

/** Wikipedia's summaries by URL; any other page is a 404. Records what was asked. */
const wikipediaPages = (pages: Record<string, object>) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    asked.push(url)
    const page = pages[url]
    return page
      ? new Response(JSON.stringify(page), { status: 200 })
      : new Response(null, { status: 404 })
  }) as unknown as typeof fetch)
  return asked
}

const summary = (wiki: string, title: string) =>
  `https://${wiki}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`

const photo = (name: string) => ({
  type: 'standard',
  thumbnail: { source: `https://upload.wikimedia.org/330px-${name}.jpg` },
  originalimage: { source: `https://upload.wikimedia.org/${name}.jpg` },
})

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('portraitOf', () => {
  test('takes the thumbnail of the page the model named', async () => {
    wikipediaPages({ [summary('en', 'Ursula_K._Le_Guin')]: photo('le-guin') })

    const portrait = await portraitOf(AuthorName('Ursula Le Guin'), 'Ursula K. Le Guin')

    expect(String(portrait)).toBe('https://upload.wikimedia.org/330px-le-guin.jpg')
  })

  // The model came back with no title, or one that does not exist: the
  // author's own name still finds their page.
  test('falls back on the author’s name when the model’s title finds nothing', async () => {
    wikipediaPages({ [summary('en', 'Pierre_Bottero')]: photo('bottero') })

    expect(String(await portraitOf(AuthorName('Pierre Bottero'), 'Pierre Bottero (writer)'))).toBe(
      'https://upload.wikimedia.org/330px-bottero.jpg',
    )
    expect(String(await portraitOf(AuthorName('Pierre Bottero')))).toBe(
      'https://upload.wikimedia.org/330px-bottero.jpg',
    )
  })

  test('looks on the French Wikipedia for an author the English one has no photo of', async () => {
    wikipediaPages({
      [summary('en', 'Jean-Luc_Istin')]: { type: 'standard' },
      [summary('fr', 'Jean-Luc_Istin')]: photo('istin'),
    })

    expect(String(await portraitOf(AuthorName('Jean-Luc Istin')))).toBe(
      'https://upload.wikimedia.org/330px-istin.jpg',
    )
  })

  test('prefers the model’s page over a namesake found by name', async () => {
    wikipediaPages({
      [summary('en', 'John_Smith_(novelist)')]: photo('novelist'),
      [summary('en', 'John_Smith')]: photo('explorer'),
    })

    expect(String(await portraitOf(AuthorName('John Smith'), 'John Smith (novelist)'))).toBe(
      'https://upload.wikimedia.org/330px-novelist.jpg',
    )
  })

  test('refuses a disambiguation page, a list of namesakes', async () => {
    wikipediaPages({
      [summary('en', 'Paul_Martin')]: { ...photo('someone'), type: 'disambiguation' },
    })

    expect(await portraitOf(AuthorName('Paul Martin'))).toBeUndefined()
  })

  test('asks each page once when the model’s title is the name', async () => {
    const asked = wikipediaPages({})

    await portraitOf(AuthorName('Fred Vargas'), 'Fred Vargas')

    expect(asked).toEqual([summary('en', 'Fred_Vargas'), summary('fr', 'Fred_Vargas')])
  })

  test('gives up quietly when Wikipedia is unreachable', async () => {
    spyOn(globalThis, 'fetch').mockImplementation((async () => {
      throw new Error('The operation was aborted due to timeout')
    }) as unknown as typeof fetch)

    expect(await portraitOf(AuthorName('Fred Vargas'))).toBeUndefined()
  })
})
