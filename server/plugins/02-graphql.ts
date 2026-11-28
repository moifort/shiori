import { ApolloServer, type ApolloServerPlugin } from '@apollo/server'
import { unwrapResolverError } from '@apollo/server/errors'
import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default'
import * as Sentry from '@sentry/node'
import { GraphQLError } from 'graphql'
import { discoveryProjectionInvalidation } from '~/domain/discovery/infrastructure/graphql/projection-invalidation'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'
import { schema } from '~/domain/shared/graphql/schema'
import { logBootSteps, markBootStep } from '~/system/boot-marks'
import { createLogger } from '~/system/logger'
import { startReadMeter } from '~/system/read-meter'
import { isSubscriptionRequired } from '~/system/subscriber-gate'
import { setApollo } from '~/utils/apollo'
import { clientBuildOf, userAgentOf } from '~/utils/client-build'

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
        // A paid call refused for want of Premium is the gate working, not a fault.
        .filter((cause) => !isSubscriptionRequired(cause))
      if (unexpected.length === 0) return
      for (const cause of unexpected) Sentry.captureException(cause)
      // Cloud Functions gen2 throttles the CPU once the response is sent —
      // flush now or the event may never leave the instance.
      await Sentry.flush(2000)
    },
  }),
}

// The code an error reaches the app with: the resolver's own, `PREMIUM_REQUIRED` for a paid
// call the subscriber gate refused deep inside a resolver, `INTERNAL_SERVER_ERROR` otherwise.
const codeOf = (error: GraphQLError): string =>
  isSubscriptionRequired(error.originalError)
    ? 'PREMIUM_REQUIRED'
    : typeof error.extensions?.code === 'string'
      ? error.extensions.code
      : 'INTERNAL_SERVER_ERROR'

// One line per operation, to find the slow screens and the refusals: which operation, how
// long it took, the Firestore reads it made, who asked, the client (a build run from Xcode is
// flagged, so a count of readers can leave it out) and the codes of the errors it answered. A
// refusal (`QUOTA_EXHAUSTED`, `PREMIUM_REQUIRED`) is a domain error, never sent to Sentry, so
// this line is where refusals are counted. Info level, so never sent to Sentry; in a built
// bundle the context keys land under `jsonPayload`, where Cloud Logging can sum them per
// operation.
const operationMetrics: ApolloServerPlugin<GraphQLContext> = {
  requestDidStart: async ({ contextValue }) => {
    const started = performance.now()
    const reads = startReadMeter(contextValue.event.context)
    const client = clientBuildOf(userAgentOf(contextValue.event))
    return {
      willSendResponse: async ({ operationName, operation, errors }) => {
        logger.info('operation served', {
          operation: operationName ?? 'anonymous',
          type: operation?.operation,
          durationMs: Math.round(performance.now() - started),
          ...reads,
          reads: reads.docReads + reads.queryDocs,
          errors: errors?.length ?? 0,
          ...(errors?.length ? { errorCodes: errors.map(codeOf) } : {}),
          userId: contextValue.userId,
          ...client,
        })
      },
    }
  },
}

export default defineNitroPlugin(async () => {
  const plugins: ApolloServerPlugin<GraphQLContext>[] = [
    sentryErrorCapture,
    operationMetrics,
    discoveryProjectionInvalidation,
  ]
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
    // A paid call the subscriber gate refused inside a resolver that does not map it reaches
    // the app as `PREMIUM_REQUIRED`, never as an internal error.
    formatError: (formatted, error) =>
      isSubscriptionRequired(unwrapResolverError(error))
        ? {
            ...formatted,
            message: 'This needs an active subscription',
            extensions: { code: 'PREMIUM_REQUIRED' },
          }
        : formatted,
  })
  await apollo.start()
  setApollo(apollo)
  if (import.meta.dev) return
  markBootStep('apolloMs')
  logBootSteps()
})
