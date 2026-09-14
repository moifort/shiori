// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Identifier of a series in the shared catalogue, derived from its name and author rather than random.
  ///
  /// Deterministic on purpose: two readers scanning volumes of the same saga must reach the same catalogue document, so it is paid for once. Diacritics are folded and a leading article dropped. Example: "wheel-of-time--robert-jordan".
  typealias SeriesId = String

}