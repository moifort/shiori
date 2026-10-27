import {
  inPageOrder,
  isPortraitWorthSeeking,
  standaloneBooksOf,
} from '~/domain/author/business-rules'
import type { PortraitUrl } from '~/domain/author/types'
import { BookQuery } from '~/domain/book/query'
import type { Book, NarratorName } from '~/domain/book/types'
import { shelvedNarratorsOf, unshelvedNarratorOf } from '~/domain/narrator/business-rules'
import { NarratorCommand } from '~/domain/narrator/command'
import { NarratorQuery } from '~/domain/narrator/query'
import type { Narrator, NarratorKey, ShelvedNarrator } from '~/domain/narrator/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'

/** A narrator as their page draws them: what the library says, their face,
 *  and the reader's own heart on them, apart from the hearts their recordings
 *  and sagas carry. */
export type FollowedNarrator = ShelvedNarrator<Book> & {
  portraitUrl?: PortraitUrl
  favorite?: boolean
}

/** Everything a narrator's page draws, in one answer. */
export type NarratorPage = {
  narrator: FollowedNarrator
  /** The reader's sagas heard in their voice, read into first. */
  sagas: FollowedSeries[]
  /** The reader's recordings of theirs outside any saga, listened ones first. */
  books: Book[]
}

export namespace NarratorUseCase {
  /** A narrator's page: the reader's recordings in their voice, grouped as an
   *  author's are, and their portrait — sought on Wikipedia the first time
   *  anybody opens it, and again a month after a miss. Free: no model call.
   *
   *  A narrator the reader holds nothing of — named by a friend's recording —
   *  is drawn from the name `offered`. Null without it, or when it names
   *  somebody else. */
  export const page = async (
    userId: UserId,
    key: NarratorKey,
    offered?: NarratorName,
  ): Promise<NarratorPage | null> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const shelved =
      shelvedNarratorsOf(books, opinions).find((narrator) => narrator.key === key) ??
      (offered ? unshelvedNarratorOf<Book>(key, offered, new Date()) : null)
    if (!shelved) return null
    const [face, sagas, hearted] = await Promise.all([
      faceOf(shelved),
      SeriesUseCase.followedAmong(userId, new Set(shelved.seriesIds)),
      NarratorQuery.favoriteKeys(userId),
    ])
    return {
      narrator: { ...shelved, portraitUrl: face?.portraitUrl, favorite: hearted.has(key) },
      sagas: inPageOrder(sagas),
      books: standaloneBooksOf(shelved.books),
    }
  }

  /** The stored face, sought again when there is none and it was not sought
   *  lately. */
  const faceOf = async (shelved: ShelvedNarrator<Book>): Promise<Narrator | null> => {
    const known = await NarratorQuery.byKey(shelved.key)
    if (known && !isPortraitWorthSeeking(known, new Date())) return known
    return NarratorCommand.seekPortrait(known, shelved.key, shelved.name)
  }
}
