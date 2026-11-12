import type { ApolloServerPlugin } from '@apollo/server'
import { Kind, type OperationDefinitionNode } from 'graphql'
import { DiscoveryCommand } from '~/domain/discovery/command'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'
import { createLogger } from '~/system/logger'

const logger = createLogger('discovery')

/** The mutations that change nothing a Découvrir tab is drawn from: devices,
 *  friends, the account's look, the lookups that only answer. Any other one
 *  marks the reader's projections stale — one forgotten here only costs a tab
 *  worked out again. `lookUpDiscovery` keeps the projection it works out
 *  itself, and `deleteAccount` must not leave a document behind. */
const LEAVE_DISCOVERY_ALONE = new Set([
  'acceptFriendInvitation',
  'changeAvatar',
  'completeOnboarding',
  'deleteAccount',
  'describeRelease',
  'detectBooks',
  'inviteFriend',
  'lookUpDiscovery',
  'registerDevice',
  'removeFriend',
  'scanTitle',
  'searchTitle',
  'startAudibleLogin',
  'startKindleLogin',
  'syncEntitlement',
  'unregisterDevice',
])

const rootFieldsOf = (operation: OperationDefinitionNode) =>
  operation.selectionSet.selections.flatMap((selection) =>
    selection.kind === Kind.FIELD ? [selection.name.value] : ['(fragment)'],
  )

/** After a reader's mutation, before its answer leaves: the projections of
 *  their Découvrir tab are stale, so the next opening works the tab out again
 *  rather than read rows the mutation outdated. Marked even when the mutation
 *  failed part way: what it wrote before failing counts. */
export const discoveryProjectionInvalidation: ApolloServerPlugin<GraphQLContext> = {
  requestDidStart: async () => ({
    willSendResponse: async ({ operation, contextValue }) => {
      if (operation?.operation !== 'mutation' || !contextValue.userId) return
      if (rootFieldsOf(operation).every((field) => LEAVE_DISCOVERY_ALONE.has(field))) return
      await DiscoveryCommand.recordLibraryChange([contextValue.userId]).catch((error) =>
        logger.warn('discovery projection not marked stale', { error }),
      )
    },
  }),
}
