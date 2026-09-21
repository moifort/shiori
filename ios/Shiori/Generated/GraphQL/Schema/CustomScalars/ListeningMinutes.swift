// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. An audiobook running time in whole minutes.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// An audiobook running time in whole minutes, 1 to 60000. Absent when unknown. Example: 870 for 14 h 30.
  typealias ListeningMinutes = Int

}
