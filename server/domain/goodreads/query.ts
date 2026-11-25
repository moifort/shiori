import * as repository from '~/domain/goodreads/infrastructure/repository'
import type { GoodreadsImport } from '~/domain/goodreads/types'
import type { UserId } from '~/domain/shared/types'

export namespace GoodreadsQuery {
  /** The reader's last import, or nothing when they never imported. */
  export const lastImport = (userId: UserId): Promise<GoodreadsImport | undefined> =>
    repository.findByUser(userId)
}
