import { builder } from './builder'

// Custom scalars must be registered before any type that references them.
import './scalars'

// Domain GraphQL layers, imported as they come online. Each domain owns its
// enums.ts, types.ts, inputs.ts, queries.ts and mutations.ts under
// infrastructure/graphql/.

// Series domain (the shared saga catalogue). Its enums are registered before the
// book types, which reference VolumeKind on a book series membership.
import '~/domain/series/infrastructure/graphql/enums'
import '~/domain/series/infrastructure/graphql/types'

// Book domain (the reader own library)
import '~/domain/book/infrastructure/graphql/enums'
import '~/domain/book/infrastructure/graphql/types'
import '~/domain/book/infrastructure/graphql/inputs'
import '~/domain/book/infrastructure/graphql/queries'
import '~/domain/book/infrastructure/graphql/mutations'

// Series queries come last: mySeries reads the library, so it depends on the
// book domain being registered.
import '~/domain/series/infrastructure/graphql/queries'

export const schema = builder.toSchema()
