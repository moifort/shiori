import * as favoriteRepository from '~/domain/narrator/infrastructure/favorite-repository'
import * as repository from '~/domain/narrator/infrastructure/repository'
import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import type { UserId } from '~/domain/shared/types'

export namespace NarratorQuery {
  export const byKey = (key: NarratorKey): Promise<Narrator | null> => repository.findByKey(key)

  /** The narrators the reader hearted, by key: one query a request. */
  export const favoriteKeys = async (userId: UserId): Promise<Set<NarratorKey>> =>
    new Set(
      (await favoriteRepository.findAllByUser(userId)).map((favorite) => favorite.narratorKey),
    )
}
