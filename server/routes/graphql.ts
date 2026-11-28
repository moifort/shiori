import { type ApolloServer, HeaderMap } from '@apollo/server'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { EntitlementUseCase } from '~/domain/entitlement/use-case'
import type { UserId } from '~/domain/shared/types'
import type { SubscriberGateContext } from '~/system/subscriber-gate'

export default defineEventHandler(async (event) => {
  const apollo = useApollo()
  const userId = (event.context as { userId?: UserId }).userId
  if (!userId) throw createError({ statusCode: 401, statusMessage: 'Missing user context' })
  // A TestFlight tester is Premium from their first request: asked of App Store Connect at
  // most once a day, and only for an account without a store subscription.
  await EntitlementUseCase.checkTestFlightTester(userId, event.context.userEmail)
  // No free plan: the paid model calls this request makes need its caller to be Premium.
  ;(event.context as SubscriberGateContext)._isSubscriber = async () =>
    (await EntitlementQuery.planOf(userId)) === 'premium'
  // No loader set: a book carries its series name and volume number, so grouping
  // a library reads no catalogue document. The request cache in the repositories
  // covers the rest.
  const context = async () => ({ event, userId })

  const headerMap = new HeaderMap()
  for (const [key, value] of Object.entries(getHeaders(event))) {
    if (value !== undefined) headerMap.set(key, value)
  }

  if (event.method === 'GET') {
    const query = getQuery(event)
    const search = new URLSearchParams()
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined) search.set(key, String(value))
    }
    const response = await apollo.executeHTTPGraphQLRequest({
      httpGraphQLRequest: {
        method: 'GET',
        headers: headerMap,
        body: undefined,
        search: search.toString(),
      },
      context,
    })
    return sendApolloResponse(event, response)
  }

  const body = await readBody(event)
  const response = await apollo.executeHTTPGraphQLRequest({
    httpGraphQLRequest: { method: 'POST', headers: headerMap, body, search: '' },
    context,
  })
  return sendApolloResponse(event, response)
})

function sendApolloResponse(
  event: Parameters<typeof setResponseStatus>[0],
  response: Awaited<ReturnType<ApolloServer['executeHTTPGraphQLRequest']>>,
) {
  setResponseStatus(event, response.status || 200)
  for (const [key, value] of response.headers) setResponseHeader(event, key, value)
  if (response.body.kind === 'complete') return response.body.string
  throw createError({ statusCode: 500, statusMessage: 'Chunked responses not supported' })
}
