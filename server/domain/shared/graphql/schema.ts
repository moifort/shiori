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

// Series queries come last among the core domains: mySeries reads the library,
// so it depends on the book domain being registered.
import '~/domain/series/infrastructure/graphql/queries'
import '~/domain/series/infrastructure/graphql/mutations'

// What a reader makes of a saga, kept out of the catalogue on purpose: `series`
// is a fact about the world with no reader in it. After series, whose SeriesId
// scalar it borrows.
import '~/domain/series-opinion/infrastructure/graphql/types'
import '~/domain/series-opinion/infrastructure/graphql/queries'
import '~/domain/series-opinion/infrastructure/graphql/mutations'

// Authors (the Library tab's third shelf, derived from the books). After series
// and series-opinion: an author row shows a saga as the Series tab draws it.
import '~/domain/author/infrastructure/graphql/queries'
import '~/domain/author/infrastructure/graphql/mutations'

// Analytics (the home dashboard, read from a view the book writes keep fresh).
// After book and series: it borrows their scalars and the Genre enum.
import '~/domain/analytics/infrastructure/graphql/types'
import '~/domain/analytics/infrastructure/graphql/queries'

// User domain (profile and onboarding state)
import '~/domain/user/infrastructure/graphql/types'
import '~/domain/user/infrastructure/graphql/inputs'
import '~/domain/user/infrastructure/graphql/queries'
import '~/domain/user/infrastructure/graphql/mutations'

// Entitlement domain (what the App Store sold, and the plan it grants)
import '~/domain/entitlement/infrastructure/graphql/enums'
import '~/domain/entitlement/infrastructure/graphql/types'
import '~/domain/entitlement/infrastructure/graphql/queries'
import '~/domain/entitlement/infrastructure/graphql/mutations'

// Quota domain (the monthly scan allowance, read against the plan)
import '~/domain/quota/infrastructure/graphql/types'
import '~/domain/quota/infrastructure/graphql/queries'

// Scan (cover reading via Gemini). After book and series: its result type
// borrows their scalars and the VolumeKind enum.
import '~/domain/scan/infrastructure/graphql/types'
import '~/domain/scan/infrastructure/graphql/mutations'

// Audible (importing the reader's audiobook library). After book and series:
// its importable book borrows their scalars and the ReadingStatus enum.
import '~/domain/audible/infrastructure/graphql/enums'
import '~/domain/audible/infrastructure/graphql/types'
import '~/domain/audible/infrastructure/graphql/queries'
import '~/domain/audible/infrastructure/graphql/mutations'

// Kindle (cataloguing a library from the Amazon data export). After book: its
// importable book borrows the book scalars.
import '~/domain/kindle/infrastructure/graphql/types'
import '~/domain/kindle/infrastructure/graphql/mutations'

// Friendship (sharing a library with somebody). After book and series: a
// friend's shelf borrows their scalars and enums.
import '~/domain/friendship/infrastructure/graphql/types'
import '~/domain/friendship/infrastructure/graphql/queries'
import '~/domain/friendship/infrastructure/graphql/mutations'

// Notification (push alerts about books coming out)
import '~/domain/notification/infrastructure/graphql/enums'
import '~/domain/notification/infrastructure/graphql/types'
import '~/domain/notification/infrastructure/graphql/queries'
import '~/domain/notification/infrastructure/graphql/mutations'

// Discover (the Découvrir tab). After friendship and notification: a friend's
// heart opens as a friend book, and a release names its alert kind.
import '~/domain/discover/infrastructure/graphql/types'
import '~/domain/discover/infrastructure/graphql/queries'
import '~/domain/discover/infrastructure/graphql/mutations'

// Changelog (application release notes)
import '~/domain/changelog/infrastructure/graphql/types'
import '~/domain/changelog/infrastructure/graphql/queries'

// Admin (the app's own economics, for the in-app admin screen). Last: it reads
// the user domain to gate itself on the admin flag.
import '~/domain/admin/infrastructure/graphql/types'
import '~/domain/admin/infrastructure/graphql/queries'

export const schema = builder.toSchema()
