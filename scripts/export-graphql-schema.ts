// Standalone script that exports the Pothos schema as SDL into shared/schema.graphql.
// Usage: bun run generate:graphql
// Run after any change to a domain's GraphQL types/queries/mutations so that
// the iOS Apollo codegen picks up the new shape.
import { printSchema } from 'graphql'
import { schema } from '../server/domain/shared/graphql/schema'

const sdl = printSchema(schema)
await Bun.write('shared/schema.graphql', sdl)

process.stdout.write('Exported GraphQL schema to shared/schema.graphql\n')
