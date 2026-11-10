import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import {
  type DefinitionNode,
  type FragmentDefinitionNode,
  graphql,
  Kind,
  type OperationDefinitionNode,
  parse,
  print,
  visit,
} from 'graphql'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/domain/suggestion/infrastructure/claude', () => ({
  isConfigured: () => true,
  ask: async () => '[]',
}))
mock.module('~/domain/suggestion/infrastructure/catalogue', () => ({ coverOf: async () => null }))

const { schema } = await import('~/domain/shared/graphql/schema')
const { BookUseCase } = await import('~/domain/book/use-case')
const { SeriesName, VolumeNumber, seriesKeyOf } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle, StarRating } = await import('~/domain/shared/primitives')

// The app's own operations, read from the iOS sources, so the budget below is
// the one the installed app pays rather than a query written for the test.
const features = join(import.meta.dir, '../../../../ios/Shiori/Features')
const definitions: DefinitionNode[] = readdirSync(features).flatMap((feature) => {
  const folder = join(features, feature, 'GraphQL')
  try {
    return readdirSync(folder)
      .filter((file) => file.endsWith('.graphql'))
      .flatMap((file) => parse(readFileSync(join(folder, file), 'utf8')).definitions)
  } catch {
    return []
  }
})
const fragments = new Map(
  definitions
    .filter((node): node is FragmentDefinitionNode => node.kind === Kind.FRAGMENT_DEFINITION)
    .map((node) => [node.name.value, node]),
)
const operations = new Map(
  definitions
    .filter((node): node is OperationDefinitionNode => node.kind === Kind.OPERATION_DEFINITION)
    .map((node) => [node.name?.value ?? '', node]),
)

/** The operation as the app sends it: itself and every fragment it spreads. */
const documentOf = (name: string): string => {
  const operation = operations.get(name)
  if (!operation) throw new Error(`No operation ${name} in the iOS sources`)
  const needed = new Map<string, FragmentDefinitionNode>()
  const collect = (node: OperationDefinitionNode | FragmentDefinitionNode) =>
    visit(node, {
      FragmentSpread: ({ name: { value } }) => {
        const fragment = fragments.get(value)
        if (!fragment || needed.has(value)) return
        needed.set(value, fragment)
        collect(fragment)
      },
    })
  collect(operation)
  return [operation, ...needed.values()].map(print).join('\n')
}

const reader = 'reader' as UserId
const french = { node: { req: { headers: { 'accept-language': 'fr-FR' } } } }

let fake: FakeFirestore

/** What Firestore bills: documents read by reference and documents queries returned. */
const billed = () => fake.docReads + fake.queriedDocs

/** One HTTP request: its own request cache, as the server gives each. */
const request = async (name: string, variableValues: Record<string, unknown> = {}) => {
  startFakeRequest()
  const before = { billed: billed(), queriedDocs: fake.queriedDocs }
  const result = await graphql({
    schema,
    source: documentOf(name),
    variableValues,
    contextValue: { event: french, userId: reader },
  })
  expect(result.errors).toBeUndefined()
  return { billed: billed() - before.billed, queriedDocs: fake.queriedDocs - before.queriedDocs }
}

const total = (requests: { billed: number }[]) =>
  requests.reduce((sum, { billed }) => sum + billed, 0)

const LIBRARY_SIZE = 100

beforeEach(async () => {
  fake = resetFakeFirestore()
  // Twelve sagas of five volumes, a third of them recordings, and forty
  // standalone novels: a library the size the production average reads.
  for (let saga = 0; saga < 12; saga++) {
    const format = saga % 3 === 0 ? 'audiobook' : 'book'
    const author = `Author ${saga % 6}`
    for (let volume = 1; volume <= 5; volume++) {
      const added = await BookUseCase.add(reader, {
        title: BookTitle(`Saga ${saga}, volume ${volume}`),
        authors: [AuthorName(author)],
        status: volume < 3 ? 'read' : 'to-read',
        language: 'fr',
        format,
        series: {
          saga: seriesKeyOf(`Saga ${saga}`, author, format),
          name: SeriesName(`Saga ${saga}`),
          volume: VolumeNumber(volume),
          kind: 'main',
        },
      })
      if (volume === 1 && typeof added === 'object' && 'id' in added)
        await BookUseCase.rate(reader, added.id, StarRating(5))
    }
  }
  for (let novel = 0; novel < 40; novel++)
    await BookUseCase.add(reader, {
      title: BookTitle(`Novel ${novel}`),
      authors: [AuthorName(`Novelist ${novel % 10}`)],
      status: 'read',
      language: 'fr',
    })
})

describe("the home's opening", () => {
  test('reads the library once a request, in two requests rather than six', async () => {
    const separate = [
      await request('Dashboard', { timeZone: 'Europe/Paris' }),
      await request('MonthlyDiscoveries', { format: 'BOOK', lookUp: false }),
      await request('Discovery', { format: 'BOOK' }),
      await request('Discovery', { format: 'AUDIOBOOK' }),
      await request('AwaitedEditions', { format: 'BOOK' }),
      await request('AwaitedEditions', { format: 'AUDIOBOOK' }),
    ]
    const top = await request('HomeOpening', { timeZone: 'Europe/Paris' })
    const releases = await request('HomeReleases')

    // Each composed request scans the library once, whatever it holds.
    expect(top.queriedDocs).toBeLessThan(2 * LIBRARY_SIZE)
    expect(releases.queriedDocs).toBeLessThan(2 * LIBRARY_SIZE)
    expect(total([top, releases])).toBeLessThan(total(separate) * 0.6)
    expect(total([top, releases])).toBeLessThanOrEqual(280)
  })
})

describe("the Actu tab's opening", () => {
  test('reads the library once, in one request rather than six', async () => {
    const separate = [
      await request('NewsFeed', { limit: 20 }),
      await request('UpcomingReleases'),
      await request('YearReleases'),
      await request('NarratorNews'),
      await request('AwardSections', { format: 'BOOK' }),
      await request('MonthlyDiscoveries', { format: 'BOOK', lookUp: false }),
    ]
    const opening = await request('NewsOpening', { limit: 20 })

    expect(opening.queriedDocs).toBeLessThan(2 * LIBRARY_SIZE)
    expect(opening.billed).toBeLessThan(total(separate) * 0.35)
    expect(opening.billed).toBeLessThanOrEqual(200)
  })
})
