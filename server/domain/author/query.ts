import * as favoriteRepository from '~/domain/author/infrastructure/favorite-repository'
import { openLibraryPortraitOf } from '~/domain/author/infrastructure/open-library'
import * as repository from '~/domain/author/infrastructure/repository'
import { wikidataPortraitOf } from '~/domain/author/infrastructure/wikidata'
import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import type {
  Author,
  AuthorKey,
  AuthorMiss,
  PortraitSource,
  PortraitUrl,
} from '~/domain/author/types'
import type { AuthorName, UserId } from '~/domain/shared/types'

export namespace AuthorQuery {
  export const byKey = (key: AuthorKey): Promise<Author | undefined> => repository.findByKey(key)

  export const byKeys = (keys: readonly AuthorKey[]): Promise<Author[]> =>
    keys.length === 0 ? Promise.resolve([]) : repository.findManyByKeys(keys)

  /** When the catalogue call last failed to describe this author, if it did. */
  export const lastMiss = (key: AuthorKey): Promise<AuthorMiss | undefined> =>
    repository.findMiss(key)

  /** The authors the reader hearted, by key: one query a request. */
  export const favoriteKeys = async (userId: UserId): Promise<Set<AuthorKey>> =>
    new Set((await favoriteRepository.findAllByUser(userId)).map((favorite) => favorite.authorKey))

  /** The photograph Wikipedia shows for a name, the page the model named
   *  tried first: shared with the narrators, whose faces Wikipedia alone
   *  knows. Never throws. */
  export const wikipediaPortraitOf = (
    name: AuthorName,
    pageTitle?: string,
  ): Promise<PortraitUrl | undefined> => portraitOf(name, pageTitle)

  /** Every face the free sources find for a name, each once, in the order
   *  they are trusted. Asked at once, so a miss costs one timeout; a source
   *  with nothing is left out. */
  export const portraitsFor = async (
    name: AuthorName,
  ): Promise<{ source: PortraitSource; url: PortraitUrl }[]> => {
    const [wikipedia, wikidata, openLibrary] = await Promise.all([
      portraitOf(name),
      wikidataPortraitOf(name),
      openLibraryPortraitOf(name),
    ])
    const found = [
      { source: 'wikipedia' as const, url: wikipedia },
      { source: 'wikidata' as const, url: wikidata },
      { source: 'openLibrary' as const, url: openLibrary },
    ].flatMap(({ source, url }) => (url ? [{ source, url }] : []))
    return found.filter(
      (choice, index) => found.findIndex((other) => other.url === choice.url) === index,
    )
  }
}
