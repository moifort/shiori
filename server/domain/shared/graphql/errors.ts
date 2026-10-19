import { GraphQLError } from 'graphql'

// Throwing helpers for resolvers: the `never` return type lets them sit in
// match() arms while the success arms keep the resolver's inferred type.
export const domainError = (code: string, message: string): never => {
  throw new GraphQLError(message, { extensions: { code } })
}

export const notFound = (message: string): never => domainError('NOT_FOUND', message)

/** The model cannot be asked: our Gemini credit is spent. Its own code, so the
 *  app tells the reader to come back later rather than that their book was not
 *  found. */
export const aiUnavailable = (): never =>
  domainError('AI_UNAVAILABLE', 'The AI is unavailable for now; nothing was spent')

export const forbidden = (message: string): never => domainError('FORBIDDEN', message)

export const badUserInput = (message: string): never => domainError('BAD_USER_INPUT', message)
