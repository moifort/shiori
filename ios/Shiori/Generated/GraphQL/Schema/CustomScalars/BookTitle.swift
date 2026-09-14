// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// The title of a book, 1 to 300 characters.
  ///
  /// Bounded because it often comes from a model reading a cover: a 500-character "title" is a misread blurb. Example: "The Name of the Wind".
  typealias BookTitle = String

}