// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Identifier of one book in one reader library, as a UUID v4.
  ///
  /// Scoped to its owner: the same novel catalogued by two readers has two unrelated ids. Example: "f9b1c2d0-4e3a-4c21-9f77-1a2b3c4d5e6f".
  typealias BookId = String

}