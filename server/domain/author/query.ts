import * as repository from '~/domain/author/infrastructure/repository'
import type { Author, AuthorKey, AuthorMiss } from '~/domain/author/types'

export namespace AuthorQuery {
  export const byKey = (key: AuthorKey): Promise<Author | null> => repository.findByKey(key)

  export const byKeys = (keys: readonly AuthorKey[]): Promise<Author[]> =>
    keys.length === 0 ? Promise.resolve([]) : repository.findManyByKeys(keys)

  /** When the catalogue call last failed to describe this author, if it did. */
  export const lastMiss = (key: AuthorKey): Promise<AuthorMiss | null> => repository.findMiss(key)
}
