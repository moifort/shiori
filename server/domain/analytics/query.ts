import * as repository from '~/domain/analytics/infrastructure/repository'
import type { AnalyticsView, SharedHearts, SharedHeartsState } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'

export namespace AnalyticsQuery {
  export const view = async (userId: UserId): Promise<AnalyticsView | undefined> =>
    repository.findByUser(userId)

  /** Several readers' views, one batched read. */
  export const views = async (userIds: readonly UserId[]): Promise<AnalyticsView[]> =>
    repository.findByUsers(userIds)

  /** Several readers' projections of their hearts, one batched read, each
   *  with what tells it fresh. */
  export const hearts = async (
    userIds: readonly UserId[],
  ): Promise<(SharedHeartsState & { shared?: SharedHearts })[]> => repository.findHearts(userIds)
}
