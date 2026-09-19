// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Amazon's identifier for one audiobook: ten upper-case alphanumeric characters.
  ///
  /// Handed out by `audibleLibrary` and passed straight back to `importAudibleBooks` to say which titles to catalogue. Example: "B002V1OF70".
  typealias AudibleAsin = String

}
