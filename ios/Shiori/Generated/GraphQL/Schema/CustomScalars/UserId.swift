// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A Firebase Auth user identifier, carried as an opaque non-empty string.
  ///
  /// Every book is owned by a `UserId`; the viewer identity is derived from the request Bearer token, so this is rarely passed as an input. Example: "KyTjMU39NBhfakGxExfqLmC5OYU2".
  typealias UserId = String

}