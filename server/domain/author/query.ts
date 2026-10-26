import * as favoriteRepository from '~/domain/author/infrastructure/favorite-repository'
import * as repository from '~/domain/author/infrastructure/repository'
import type { Author, AuthorKey, AuthorMiss } from '~/domain/author/types'
import type { UserId } from '~/domain/shared/types'

export namespace AuthorQuery {
  export const byKey = (key: AuthorKey): Promise<Author | null> => repository.findByKey(key)

  export const byKeys = (keys: readonly AuthorKey[]): Promise<Author[]> =>
    keys.length === 0 ? Promise.resolve([]) : repository.findManyByKeys(keys)

  /** When the catalogue call last failed to describe this author, if it did. */
  export const lastMiss = (key: AuthorKey): Promise<AuthorMiss | null> => repository.findMiss(key)

  /** The authors the reader hearted, by key: one query a request. */
  export const favoriteKeys = async (userId: UserId): Promise<Set<AuthorKey>> =>
    new Set((await favoriteRepository.findAllByUser(userId)).map((favorite) => favorite.authorKey))
}
