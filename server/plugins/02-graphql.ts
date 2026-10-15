import { ApolloServer, type ApolloServerPlugin } from '@apollo/server'
import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default'
import * as Sentry from '@sentry/node'
import { GraphQLError } from 'graphql'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'
import { schema } from '~/domain/shared/graphql/schema'
import { createLogger } from '~/system/logger'
import { startReadMeter } from '~/system/read-meter'
import { setApollo } from '~/utils/apollo'

const logger = createLogger('graphql')

// Apollo answers resolver exceptions with HTTP 200 + errors[], so Nitro's
// `error` hook never sees them. Capture unexpected ones (anything that is not
// a deliberate GraphQLError thrown by a resolver or scalar) here instead.
const sentryErrorCapture = {
  requestDidStart: async () => ({
    didEncounterErrors: async ({ errors }: { errors: readonly GraphQLError[] }) => {
      const unexpected = errors
        .map((error) => error.originalError)
        .filter((cause): cause is Error => cause !== undefined && !(cause instanceof GraphQLError))
      if (unexpected.length === 0) return
      for (const cause of unexpected) Sentry.captureException(cause)
      // Cloud Functions gen2 throttles the CPU once the response is sent —
      // flush now or the event may never leave the instance.
      await Sentry.flush(2000)
    },
  }),
}

// One line per operation, to find the slow screens: which operation, how long
// it took, and the Firestore reads it made. Info level, so never sent to Sentry;
// in a built bundle the context keys land under `jsonPayload`, where Cloud
// Logging can sum them per operation.
const operationMetrics: ApolloServerPlugin<GraphQLContext> = {
  requestDidStart: async ({ contextValue }) => {
    const started = performance.now()
    const reads = startReadMeter(contextValue.event.context)
    return {
      willSendResponse: async ({ operationName, operation, errors }) => {
        logger.info('operation served', {
          operation: operationName ?? 'anonymous',
          type: operation?.operation,
          durationMs: Math.round(performance.now() - started),
          ...reads,
          reads: reads.docReads + reads.queryDocs,
          errors: errors?.length ?? 0,
        })
      },
    }
  },
}

export default defineNitroPlugin(async () => {
  const plugins: ApolloServerPlugin<GraphQLContext>[] = [sentryErrorCapture, operationMetrics]
  // Dev-only: serve the embedded Apollo Sandbox on GET /graphql (Accept: text/html).
  if (import.meta.dev) plugins.push(ApolloServerPluginLandingPageLocalDefault({ embed: true }))
  const apollo = new ApolloServer<GraphQLContext>({
    schema,
    introspection: true,
    plugins,
    // Apollo is externalized in the bundle, so it would otherwise decide this from the
    // runtime NODE_ENV, which nothing in infra/function.tf sets. Pin it to the
    // compile-time flag so prod never returns stack traces to a client.
    includeStacktraceInErrorResponses: import.meta.dev,
  })
  await apollo.start()
  setApollo(apollo)
})
