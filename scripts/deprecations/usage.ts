import {
  type GraphQLSchema,
  isEnumType,
  isInputObjectType,
  isInterfaceType,
  isObjectType,
  parse,
  TypeInfo,
  visit,
  visitWithTypeInfo,
} from 'graphql'

/** A deprecated element of the schema, named by its schema coordinate. Only a
 *  field or an argument can be traced through the app's operations: an input
 *  field is filled from Swift through a variable, and an enum value travels in
 *  responses, so neither shows in the `.graphql` files. */
export type DeprecatedElement = { coordinate: string; traceable: boolean }

export const deprecatedElementsOf = (schema: GraphQLSchema): DeprecatedElement[] =>
  Object.values(schema.getTypeMap())
    .filter((type) => !type.name.startsWith('__'))
    .flatMap((type): DeprecatedElement[] => {
      if (isObjectType(type) || isInterfaceType(type)) {
        return Object.values(type.getFields()).flatMap((field) => [
          ...field.args
            .filter((arg) => arg.deprecationReason != null)
            .map((arg) => ({
              coordinate: `${type.name}.${field.name}(${arg.name}:)`,
              traceable: true,
            })),
          ...(field.deprecationReason != null
            ? [{ coordinate: `${type.name}.${field.name}`, traceable: true }]
            : []),
        ])
      }
      if (isInputObjectType(type)) {
        return Object.values(type.getFields())
          .filter((field) => field.deprecationReason != null)
          .map((field) => ({ coordinate: `${type.name}.${field.name}`, traceable: false }))
      }
      if (isEnumType(type)) {
        return type
          .getValues()
          .filter((value) => value.deprecationReason != null)
          .map((value) => ({ coordinate: `${type.name}.${value.name}`, traceable: false }))
      }
      return []
    })

/** Every field and argument coordinate the operations select. The files are
 *  read as one document, since a fragment may be spread from another file. A
 *  name the schema does not know — an old operation read against today's
 *  schema — is skipped. */
export const coordinatesUsedBy = (
  schema: GraphQLSchema,
  documents: readonly string[],
): Set<string> => {
  const used = new Set<string>()
  const typeInfo = new TypeInfo(schema)
  visit(
    parse(documents.join('\n')),
    visitWithTypeInfo(typeInfo, {
      Field: () => {
        const parent = typeInfo.getParentType()
        const field = typeInfo.getFieldDef()
        if (parent && field) used.add(`${parent.name}.${field.name}`)
      },
      Argument: () => {
        const parent = typeInfo.getParentType()
        const field = typeInfo.getFieldDef()
        const argument = typeInfo.getArgument()
        if (parent && field && argument) {
          used.add(`${parent.name}.${field.name}(${argument.name}:)`)
        }
      },
    }),
  )
  return used
}
