// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. Page count of an edition. Absent rather than zero when unknown.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Page count of this edition, 1 to 20000. Absent when unknown — never zero, which would read as a real count of nothing. Example: 662.
  typealias PageCount = Int

}