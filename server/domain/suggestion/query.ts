import type { UserId } from '~/domain/shared/types'
import * as repository from './infrastructure/repository'

export namespace SuggestionQuery {
  export const queue = (userId: UserId) => repository.findQueue(userId)

  export const dismissals = (userId: UserId) => repository.findDismissals(userId)
}
