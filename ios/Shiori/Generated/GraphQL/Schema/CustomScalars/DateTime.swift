// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A date and time serialized as an ISO 8601 string in UTC.
  ///
  /// On output a JavaScript `Date` is rendered as an ISO string; on input an ISO string is parsed back into a `Date`. Used for record timestamps (`addedAt`, `startedAt`, `finishedAt`). Example: "2026-09-14T09:30:00.000Z".
  typealias DateTime = String

}