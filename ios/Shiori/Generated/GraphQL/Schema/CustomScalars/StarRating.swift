// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. A reader rating, 1 to 5 whole stars.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A reader rating, 1 to 5 whole stars.
  ///
  /// Whole stars only: half stars double the value space without adding discernment. Setting a rating also marks the book as read. Example: 4.
  typealias StarRating = Int

}