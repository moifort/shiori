import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import type { NarratorName } from '~/domain/book/types'
import * as favoriteRepository from '~/domain/narrator/infrastructure/favorite-repository'
import * as repository from '~/domain/narrator/infrastructure/repository'
import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('narrator')

export namespace NarratorCommand {
  /** Heart a narrator, or take the heart back: the reader's own. Answers what
   *  is now true. */
  export const setFavorite = async (
    userId: UserId,
    key: NarratorKey,
    favorite: boolean,
    at: Date = new Date(),
  ): Promise<boolean> => {
    if (favorite) await favoriteRepository.save({ userId, narratorKey: key, favoritedAt: at })
    else await favoriteRepository.remove(userId, key)
    return favorite
  }

  export const deleteFavoritesOf = (userId: UserId): Promise<void> =>
    favoriteRepository.removeAllByUser(userId)

  /** Ask Wikipedia for a narrator's face, by their name, and store what it
   *  says — the portrait, or when it was sought. Free: no model call. Never
   *  throws: the page draws the initials. */
  export const seekPortrait = async (
    known: Narrator | null,
    key: NarratorKey,
    name: NarratorName,
    at: Date = new Date(),
  ): Promise<Narrator> => {
    // A narrator's name is no author's, but Wikipedia is asked by name alone.
    const portraitUrl = await portraitOf(name as string as AuthorName)
    const entry: Narrator = portraitUrl
      ? { key, name: known?.name ?? name, portraitUrl }
      : { key, name: known?.name ?? name, portraitSoughtAt: at }
    try {
      return await repository.save(entry)
    } catch (error) {
      logger.warn('narrator portrait not recorded', { error, key })
      return entry
    }
  }
}
