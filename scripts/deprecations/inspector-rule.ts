import type { GraphQLSchema } from 'graphql'

type Change = {
  type: string
  path?: string
  message: string
  criticality: { level: string; reason?: string }
}

/** graphql-inspector's `suppressRemovalOfDeprecatedField` spares a removed field
 *  that was deprecated, not a removed argument. This rule does the same for
 *  arguments, so the deprecation routine can retire one without a red run. */
export default ({ changes, oldSchema }: { changes: Change[]; oldSchema: GraphQLSchema }) =>
  changes.map((change) => {
    if (change.type !== 'FIELD_ARGUMENT_REMOVED' || !change.path) return change
    const [typeName, fieldName, argumentName] = change.path.split('.')
    const type = oldSchema.getType(typeName)
    const field = type && 'getFields' in type ? type.getFields()[fieldName] : undefined
    const argument =
      field && 'args' in field ? field.args.find((arg) => arg.name === argumentName) : undefined
    if (argument?.deprecationReason == null) return change
    return {
      ...change,
      criticality: {
        level: 'DANGEROUS',
        reason: 'Removing a deprecated argument is a step of the deprecation routine',
      },
    }
  })
