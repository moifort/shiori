import * as repository from '~/domain/analytics/infrastructure/repository'
import type { AnalyticsView } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'

export namespace AnalyticsQuery {
  export const view = async (userId: UserId): Promise<AnalyticsView | null> =>
    repository.findByUser(userId)
}
