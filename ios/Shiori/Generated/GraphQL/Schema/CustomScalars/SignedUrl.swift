// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A time-limited URL to read one private object, signed by the server.
  ///
  /// Cover images are never public: the URL expires after an hour and must be refetched, so it is not a durable link to store client-side.
  typealias SignedUrl = String

}