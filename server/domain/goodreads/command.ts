import * as repository from '~/domain/goodreads/infrastructure/repository'
import type { GoodreadsImport } from '~/domain/goodreads/types'
import type { UserId } from '~/domain/shared/types'

export namespace GoodreadsCommand {
  export const recordImport = (record: GoodreadsImport): Promise<GoodreadsImport> =>
    repository.save(record)

  export const deleteForUser = (userId: UserId): Promise<void> => repository.remove(userId)
}
