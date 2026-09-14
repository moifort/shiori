import { ApolloServer, type ApolloServerPlugin } from '@apollo/server'
import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default'
import * as Sentry from '@sentry/node'
import { GraphQLError } from 'graphql'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'
import { schema } from '~/domain/shared/graphql/schema'
import { setApollo } from '~/utils/apollo'

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

export default defineNitroPlugin(async () => {
  const plugins: ApolloServerPlugin<GraphQLContext>[] = [sentryErrorCapture]
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
