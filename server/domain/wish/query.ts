import type { UserId } from '~/domain/shared/types'
import * as repository from '~/domain/wish/infrastructure/repository'
import type { Wish } from '~/domain/wish/types'

export namespace WishQuery {
  export const byUser = (userId: UserId): Promise<Wish[]> => repository.findAllByUser(userId)
}
