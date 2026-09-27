# API evolution — deprecation and forced update

The GraphQL schema is not versioned. Builds of the app stay installed for weeks after a
release, so the schema only ever grows, and what the app stops using leaves it in two steps:
first deprecated, then removed once a build without it has been on the App Store for two
weeks — and in that same commit, the builds that still ask for it are sent to update.

The design is [the deprecation routine spec](superpowers/specs/2026-09-27-deprecation-routine-design.md).

## Moving parts

| Piece | File |
|---|---|
| Build floor and App Store URL | `server/system/app-support.ts` (`MINIMUM_SUPPORTED_IOS_BUILD`) |
| Public config route (`GET /app-config`) | `server/routes/app-config.get.ts`, whitelisted in `server/middleware/auth.ts` |
| Launch and foreground check, fail-open, skipped in Debug | `ios/Shiori/Shared/Services/AppSupportGate.swift` |
| Blocking screen | `ios/Shiori/Shared/Components/UpdateRequiredView.swift`, wired in `AuthRoot.swift` |
| What can go, and the floor to set | `scripts/deprecations.ts` (`bun run deprecations`) |
| No breaking change without deprecation | `bun run schema:check`, the Schema workflow |
| The floor never outruns the App Store | `bun scripts/deprecations.ts check-floor`, in the Deploy workflow |

The comparison key is the build number (`CFBundleVersion`), which CI sets to
`git rev-list --count HEAD`: it names a commit and only grows, nightly or App Store alike.
Never the marketing version.

## What breaks an installed build

Removing or renaming a field, an argument or an input field; changing a type; making an
argument or an input field required; making a non-null output field nullable. Adding a field,
a query, a mutation, an optional argument or an enum value does not — the app reads an enum
value it does not know as a neutral one (`Book+GraphQL.swift`).

## The routine

1. **Deprecate, in the commit where the app stops asking.** The iOS operations
   (`ios/**/*.graphql`) stop selecting the field or argument, and the server marks it with
   `deprecationReason`, naming what replaces it. The resolver keeps working.
2. **At every App Store release, ask what can go:** `bun run deprecations` (with
   `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` set to the team key). For each deprecated
   element it finds, in git, the first build whose operations no longer select it, and
   compares it with the build on sale:
   - **removable** — a build without it has been on the App Store for fourteen days, counted
     from the `ios-v<version>` tag; or no build ever asked for it;
   - **in grace until `<date>`** — on sale, not for fourteen days yet;
   - **waiting for a release** — the App Store still sells a build that asks for it;
   - **still asked by the app** — an operation at `HEAD` selects it;
   - **check by hand** — an input field or an enum value, which the operations cannot show:
     Swift fills inputs through variables, and enum values travel in responses.
3. **Remove, in one commit:** the removable elements — schema, resolver, the code and tests
   only they used — and `MINIMUM_SUPPORTED_IOS_BUILD` set to the floor the script proposes.
   The Deploy workflow ships both together; an older build shows the update screen at its next
   launch or return to the foreground.

## Guards

- `bun run schema:check` compares `shared/schema.graphql` with `origin/main` (or
  `SCHEMA_BASE`) through `graphql-inspector`. It fails on any breaking change except the
  removal of a field or an argument that was deprecated — the second through
  `scripts/deprecations/inspector-rule.ts`, since the built-in rule spares fields only.
- `check-floor` fails the deploy when the floor is above the build on sale: readers would be
  blocked with no update to install. A floor of `1` passes without calling Apple.

## Fail-open

If `/app-config` is unreachable or undecodable, the app stays usable. A build that slips past
the gate meets GraphQL errors until its next check — never lock readers out because the check
itself failed.
