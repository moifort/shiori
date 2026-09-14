// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A 13-digit ISBN, hyphens and spaces removed, validated on its check digit.
  ///
  /// The check digit is enforced rather than assumed: models invent ISBNs that look right, and a wrong one silently poisons every later lookup. Example: "9780756404741".
  typealias Isbn13 = String

}