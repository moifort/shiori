// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. A four-digit publication year.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// A four-digit publication year, from 1450 to ten years out.
  ///
  /// The upper bound leaves room for an announced but unpublished volume, which the series catalogue keeps on purpose. Example: 2007.
  typealias Year = Int

}