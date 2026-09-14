import { GraphQLError } from 'graphql'

// Throwing helpers for resolvers: the `never` return type lets them sit in
// match() arms while the success arms keep the resolver's inferred type.
export const domainError = (code: string, message: string): never => {
  throw new GraphQLError(message, { extensions: { code } })
}

export const notFound = (message: string): never => domainError('NOT_FOUND', message)

export const forbidden = (message: string): never => domainError('FORBIDDEN', message)

export const badUserInput = (message: string): never => domainError('BAD_USER_INPUT', message)
