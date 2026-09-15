// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// An HTTPS URL to draw a book cover from.
  ///
  /// Either the reader own photo, signed and expiring after an hour, or the publisher cover found by ISBN. Neither is guaranteed to load: draw the placeholder when the image fails, and refetch the book rather than storing the URL client-side.
  typealias CoverUrl = String

}