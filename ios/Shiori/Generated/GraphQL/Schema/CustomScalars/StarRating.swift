// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. A reader rating, 1 to 5 stars in half steps.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A reader rating, 1 to 5 stars in half steps.
  ///
  /// Setting a rating also marks the book as read. Example: 3.5.
  typealias StarRating = Double

}