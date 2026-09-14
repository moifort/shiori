// @generated
// Hand-edited: the scalar is numeric, and codegen defaults every custom
// scalar to String. Position of a volume along the spine of its series.
// Apollo does not overwrite this file, which is why it is committed.
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

@_spi(Internal) @_spi(Execution) import ApolloAPI

extension ShioriGraphQL {
  /// Position of a volume along the spine of its series, 1 to 200.
  ///
  /// Absent on anything that is not a numbered main volume: a spin-off or a companion has no place in the numbering. Example: 3.
  typealias VolumeNumber = Int

}