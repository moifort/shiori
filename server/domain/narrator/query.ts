import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import type { PortraitUrl } from '~/domain/author/types'
import type { NarratorName } from '~/domain/book/types'
import * as favoriteRepository from '~/domain/narrator/infrastructure/favorite-repository'
import * as repository from '~/domain/narrator/infrastructure/repository'
import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import type { AuthorName, UserId } from '~/domain/shared/types'

export namespace NarratorQuery {
  export const byKey = (key: NarratorKey): Promise<Narrator | null> => repository.findByKey(key)

  /** Several narrators at once, in one getAll: those absent are left out. */
  export const byKeys = (keys: readonly NarratorKey[]): Promise<Narrator[]> =>
    repository.findManyByKeys(keys)

  /** The narrators the reader hearted, by key: one query a request. */
  export const favoriteKeys = async (userId: UserId): Promise<Set<NarratorKey>> =>
    new Set(
      (await favoriteRepository.findAllByUser(userId)).map((favorite) => favorite.narratorKey),
    )

  /** The face Wikipedia shows for a narrator's name, for the portrait picker.
   *  Free. Wikidata and Open Library, which an author's picker also asks,
   *  know writers only. */
  export const portraitFor = (name: NarratorName): Promise<PortraitUrl | undefined> =>
    portraitOf(name as string as AuthorName)
}
