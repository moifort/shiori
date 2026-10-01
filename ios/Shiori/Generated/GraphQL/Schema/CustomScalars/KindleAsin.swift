// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Amazon's identifier for one Kindle book: ten upper-case alphanumeric characters.
  ///
  /// Handed out by `kindleLibrary` and passed straight back to `importKindleLibrary` to say which titles to catalogue. Example: "B0G26NZ911".
  typealias KindleAsin = String

}