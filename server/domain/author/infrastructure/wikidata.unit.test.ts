import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
import { wikidataPortraitOf } from '~/domain/author/infrastructure/wikidata'
import { AuthorName } from '~/domain/shared/primitives'

const writer = { mainsnak: { datavalue: { value: { id: 'Q36180' } } } }
const filmmaker = { mainsnak: { datavalue: { value: { id: 'Q2526255' } } } }
const human = { mainsnak: { datavalue: { value: { id: 'Q5' } } } }

type Entity = {
  id: string
  label: string
  occupation: object
  image?: string
  sitelinks?: Record<string, { title: string }>
}

const entity = ({ id, label, occupation, image, sitelinks = {} }: Entity) => ({
  id,
  labels: { en: { value: label } },
  claims: {
    P31: [human],
    P106: [occupation],
    ...(image ? { P18: [{ mainsnak: { datavalue: { value: image } } }] } : {}),
  },
  sitelinks,
})

/** Wikidata answering with `entities`, Commons and the Wikipedias with a
 *  thumbnail named after the file or page asked. Records the hosts asked. */
const wikidataAnswers = (entities: ReturnType<typeof entity>[], photos: string[] = []) => {
  const asked: string[] = []
  spyOn(globalThis, 'fetch').mockImplementation((async (url: string) => {
    const { host, searchParams } = new URL(url)
    asked.push(host)
    if (searchParams.get('action') === 'wbsearchentities')
      return Response.json({ search: entities.map(({ id }) => ({ id })) })
    if (searchParams.get('action') === 'wbgetentities')
      return Response.json({ entities: Object.fromEntries(entities.map((e) => [e.id, e])) })
    const title = searchParams.get('titles') ?? ''
    const page = photos.includes(`${host}:${title}`)
      ? { thumbnail: { source: `https://upload.wikimedia.org/330px-${title}.jpg` } }
      : {}
    return Response.json({ query: { pages: { '1': page } } })
  }) as unknown as typeof fetch)
  return asked
}

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
  ;(Sentry.captureException as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('wikidataPortraitOf', () => {
  test('takes the image Wikidata records for the writer', async () => {
    wikidataAnswers(
      [entity({ id: 'Q1', label: 'Morgan Audic', occupation: writer, image: 'Audic.jpg' })],
      ['commons.wikimedia.org:File:Audic.jpg'],
    )

    expect(String(await wikidataPortraitOf(AuthorName('Morgan Audic')))).toBe(
      'https://upload.wikimedia.org/330px-File:Audic.jpg.jpg',
    )
  })

  // "Lauren Roberts" is a filmmaker on the English Wikipedia: only the writer's face will do.
  test('passes over a namesake who does not write', async () => {
    wikidataAnswers(
      [
        entity({ id: 'Q1', label: 'Lauren Roberts', occupation: filmmaker, image: 'Film.jpg' }),
        entity({ id: 'Q2', label: 'Lauren Roberts', occupation: writer, image: 'Writer.jpg' }),
      ],
      ['commons.wikimedia.org:File:Film.jpg', 'commons.wikimedia.org:File:Writer.jpg'],
    )

    expect(String(await wikidataPortraitOf(AuthorName('Lauren Roberts')))).toBe(
      'https://upload.wikimedia.org/330px-File:Writer.jpg.jpg',
    )
  })

  // Carmen Mola is three writers under one name: a pen name, not a person.
  test('takes the photograph of a collective pen name', async () => {
    const pen = entity({ id: 'Q1', label: 'Carmen Mola', occupation: writer, image: 'Mola.jpg' })
    pen.claims.P31 = [{ mainsnak: { datavalue: { value: { id: 'Q16017119' } } } }]
    wikidataAnswers([pen], ['commons.wikimedia.org:File:Mola.jpg'])

    expect(String(await wikidataPortraitOf(AuthorName('Carmen Mola')))).toBe(
      'https://upload.wikimedia.org/330px-File:Mola.jpg.jpg',
    )
  })

  test('passes over a writer under another name', async () => {
    wikidataAnswers(
      [entity({ id: 'Q1', label: 'Jasmine Masters', occupation: writer, image: 'M.jpg' })],
      ['commons.wikimedia.org:File:M.jpg'],
    )

    expect(await wikidataPortraitOf(AuthorName('Jasmine Mas'))).toBeUndefined()
  })

  // Trevanian has no photo on Wikidata, nor on the English page; the Hebrew one has.
  test('finds the photograph another language’s page shows', async () => {
    wikidataAnswers(
      [
        entity({
          id: 'Q1',
          label: 'Trevanian',
          occupation: writer,
          sitelinks: { enwiki: { title: 'Trevanian' }, hewiki: { title: 'טרוויניאן' } },
        }),
      ],
      ['he.wikipedia.org:טרוויניאן'],
    )

    expect(String(await wikidataPortraitOf(AuthorName('Trevanian')))).toBe(
      'https://upload.wikimedia.org/330px-טרוויניאן.jpg',
    )
  })

  test('finds nothing for a name Wikidata does not know', async () => {
    const asked = wikidataAnswers([])

    expect(await wikidataPortraitOf(AuthorName('SunriseCV'))).toBeUndefined()
    expect(asked).toEqual(['www.wikidata.org'])
  })

  test('gives up on a slow Wikidata, and reports it to no one', async () => {
    spyOn(globalThis, 'fetch').mockImplementation((async () => {
      throw new DOMException('The operation was aborted due to timeout', 'TimeoutError')
    }) as unknown as typeof fetch)
    const reports = spyOn(Sentry, 'captureException')

    expect(await wikidataPortraitOf(AuthorName('Fred Vargas'))).toBeUndefined()
    expect(reports).not.toHaveBeenCalled()
  })

  test('reports Wikidata failing for any other reason', async () => {
    spyOn(globalThis, 'fetch').mockImplementation((async () => {
      return new Response(null, { status: 503 })
    }) as unknown as typeof fetch)
    const reports = spyOn(Sentry, 'captureException')

    expect(await wikidataPortraitOf(AuthorName('Fred Vargas'))).toBeUndefined()
    expect(reports).toHaveBeenCalled()
  })
})
