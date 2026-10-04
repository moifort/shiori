# Shiori — Project Directives

Shiori (栞, "bookmark") turns a photo of a book cover into a catalogued, rated, annotated
record, and groups a library into series. It is built on the Vinarium stack: everything
structural is transposed from `../vinarium` rather than invented.

The design for the current scope is
[docs/superpowers/specs/2026-09-14-shiori-design.md](docs/superpowers/specs/2026-09-14-shiori-design.md).
What comes after it is in [docs/roadmap.md](docs/roadmap.md).

## Language

Everything versioned and technical is written in **English**: commit messages, code, comments,
documentation. The only non-English prose is user-facing copy: the served changelog
translations (`CHANGELOG.fr.md`) and the iOS app's on-screen text (`Localizable.xcstrings`).
The app's strings are written in French in the Swift code and translated into English in the
catalogue; English is the development language, the fallback for every other iPhone language.
Never mix languages in a commit message or a comment.

`CHANGELOG.md` is the English source of truth, `CHANGELOG.fr.md` its translation, kept in
lockstep. Version headings carry the App Store version and its release date
(`## 1.0 (2026.10.01)`). Only consequential changes are logged.

**The changelog is written at release time, never during development.** A feature, a fix or a
push leaves both files untouched; they are updated only when an actual App Store release is
cut, from the commits since the previous one, under that release's version and date.

## Commands

| Purpose | Command |
|---|---|
| Typecheck | `bunx nitro prepare && bunx tsc --noEmit` |
| Tests | `bun test` |
| Coverage | `bun test --coverage` |
| Linter | `bunx biome check` / `bun run lint:fix` |
| GraphQL schema | `bun run generate:graphql` (then `cd ios && apollo-ios-cli generate`) |
| Schema compatibility | `bun run schema:check` (breaking changes against `origin/main`) |
| Deprecations | `bun run deprecations` (what can be removed, and the build floor) |
| iOS strings | `bun scripts/check-strings.ts <derived-data> --write` after a build (French entry filled, English listed if missing) |
| Dev server | `bun run dev` |
| Build | `bun run build` |

Runtime: always `bun` / `bunx`, never `npm` / `npx`.

## Workflow

1. Verify the build before committing: `bunx nitro prepare && bunx tsc --noEmit`, `bun test`,
   `bunx biome check`, and `bun run schema:check` when the schema changed. CI is not a linter — a lint error must never be discovered from a red
   pipeline.
2. Run `bunx nitro prepare` before `tsc` if routes changed.
3. Commit freely, grouping changes as you see fit. Never touch `CHANGELOG.md` /
   `CHANGELOG.fr.md` in a feature or fix commit: they are written when an App Store release is
   cut, and only then.
4. **Never push until the user explicitly says "push".**

## API evolution

The GraphQL schema is not versioned: installed builds keep asking for what they were built
against. A field or an argument the app stops using is **deprecated in the same commit**, never
removed there. At every App Store release, `bun run deprecations` lists what a build on sale for
two weeks no longer asks for; one commit removes it and raises `MINIMUM_SUPPORTED_IOS_BUILD` to
the proposed value, which sends older builds to the update screen. Never raise the floor by
hand. The runbook is [docs/api-evolution.md](docs/api-evolution.md).

## Architecture

Domains live in `server/domain/{domain}/` with `types.ts`, `primitives.ts`, `command.ts`
(`XxxCommand` namespace), `query.ts` (`XxxQuery` namespace), optional `business-rules.ts` /
`use-case.ts`, and `infrastructure/{repository.ts, graphql/}`. Repositories are bare functions
(`import * as repository`), private to their domain.

- **Branded types** — `ts-brand` plus Zod constructors in `primitives.ts`, one GraphQL scalar
  per brand. The scalar reuses the brand's constructor rather than restating the rule.
- **Errors** — commands return bare string-literal outcomes (`'not-found' as const`) or the
  domain value; resolvers map them with `match().exhaustive()` and the `notFound` /
  `badUserInput` helpers. `throw` for impossible states.
- **Storage** — native Firestore via `db()` from `server/system/firebase.ts`, only inside
  `infrastructure/repository.ts`. Helpers in `server/utils/firestore.ts`.
- **Naming** — function names carry the business concept, not the technical pattern.
- **Observability** — never `console.*`; log via `createLogger(tag)`. Every `warn` and `error`
  is reported to Sentry, so a caught-and-recovered failure is logged, never swallowed. Keep the
  message constant and pass the rest apart — `logger.warn('cover lookup failed', { error,
  isbn13 })` — so Sentry groups one problem into one issue and keeps the stack. Sentry
  activates only in a built bundle with `NITRO_SENTRY_DSN` set.
- **Formatter** — Biome: spaces, single quotes, no semicolons, line width 100.

### What is private and what is shared

This is the rule the data model turns on, and getting it backwards is expensive:

- **Collections are flat.** Never a subcollection: every document sits in a top-level
  collection and names its owner in a `userId` field. Accounts live in `users/{userId}`.
- **A book is private.** It lives at `books/{bookId}` with its owner's `userId`, owned by
  exactly one reader, never merged with anyone else's. Two readers who scan the same novel keep two
  independent records. Status, rating and note sit on the record itself — there is no separate
  "library entry" entity.
- **A series catalogue is shared, one per edition language.** It lives at
  `series/{seriesKey}~{language}` (bare `series/{seriesKey}` for volumes that record no
  language), holds no reference to any user, and is keyed by name and author rather than
  randomly, so two readers of the same edition converge on one document and the AI call that
  produced it is paid once. A translation lists its own volumes, names, dates and covers; what
  is announced is written in by Découvrir's release watch, never by the scan. **It is never exposed through library
  sharing**, which shows books only.
- **Paper or screen is one book.** `format` says what the object is (book, manga, audiobook…),
  `media` where a read book is held (`print`, `digital`, or both). A paperback and its Kindle
  copy are one record: whatever arrives on a medium the reader lacks — a scan, a Kindle import
  or sync, `addBook` — joins the record they keep, in the same language. A recording stays its
  own record. The Kindle cover is drawn before any other (`coverSourcesOf`).
- **Every book carries `hidden`.** Sharing is not built yet; the flag exists now because adding
  a boolean to production records costs a migration.

### Series membership is denormalized on purpose

A book carries its series name and volume number. Grouping a 300-book library into sections
must not read one catalogue document per row, so the N+1 is designed out rather than batched
away — which is why the GraphQL context has no loader map. If you add a nested field that
needs the catalogue, add a per-request loader before shipping it.

## Tests

Three suffixes, three CI workflows:

- `*.unit.test.ts` — primitives and business rules, pure functions
- `*.int.test.ts` — commands and queries against the fake Firestore, with read-budget
  assertions via the split `fake.docReads` / `fake.queryReads`, never the combined `fake.reads`
- `*.feat.test.ts` — GraphQL against the built schema

Mock storage with `mock.module('~/system/firebase', () => ({ db: fakeDb }))`.

The fake Firestore has no subcollections, matching the flat layout: `collectionPath` is the
top-level collection a document lives in.

## Database migrations

Forward-only, sequential, no rollback, in `server/system/migration/migrations/`, registered in
`migrations/index.ts`, tracked in the Firestore collection `migration-meta`, triggered by
`POST /admin/migrate`. The list starts empty: Shiori has no production data yet.

**Migrate when** renaming a field, changing its structure, changing enum values, or removing
stale data. **No migration needed** for a new optional field, a new collection, or changed
query logic.

## Local development

`bun run dev` serves on port 3000. `.env` (gitignored, see `.env.example`) needs
`NITRO_DEV_USER_ID` for the dev auth bypass that lets Apollo Sandbox work without a Firebase
token, and `NITRO_SCAN_STUB=1` to answer scans with a fixed book instead of calling Gemini.
Both are `import.meta.dev` gated and tree-shaken out of a production bundle.

`NITRO_AUDIBLE_KEY` (`openssl rand -base64 32`) seals the Audible device credentials at rest.
Without it the Audible mutations fail with a clear error and nothing else breaks; changing it
makes every stored connection unreadable, so readers would have to connect again.

`NITRO_APNS_KEY_ID`, `NITRO_APNS_PRIVATE_KEY` and `NITRO_APNS_TEAM_ID` send the release
alerts through APNs. Without them every alert is logged instead of sent, and nothing else
changes.

The Firestore emulator needs a JDK and the Firebase CLI, neither of which is required for
`bun test` — the integration tests run against the in-memory fake.

## Identifiers

| | Value |
|---|---|
| Bundle ID | `com.polyforms.shiori.app` |
| GCP project | `shiori-polyforms` |
| Repository | https://github.com/moifort/shiori |
| Region | `europe-west3`, Firestore `eur3` |
