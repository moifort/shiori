# Shiori — Project Directives

Shiori (栞, "bookmark") turns a photo of a book cover into a catalogued, rated, annotated
record, and groups a library into series. It is built on the Vinarium stack: everything
structural is transposed from `../vinarium` rather than invented.

The design for the current scope is
[docs/superpowers/specs/2026-09-14-shiori-design.md](docs/superpowers/specs/2026-09-14-shiori-design.md).
What comes after it is in [docs/roadmap.md](docs/roadmap.md). The iOS app's rules — pure and
connected views, atomic layout per domain, loading, snapshots, pagination, previews and tests —
are in [docs/ios-guide.md](docs/ios-guide.md). How the design board and the app stay in sync (board first, prototyping zone, variants,
captures) is in [docs/board.md](docs/board.md); its comment workflow is Workflow rules 5–8 below.

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
| Android strings | `bun scripts/android-strings.ts` (the iOS catalogue → `android/…/assets/strings.json`) |
| Android build | `cd android && ./gradlew :app:assembleDebug` (JDK 21: `JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home`) |
| Android tests | `cd android && ./gradlew :app:testDebugUnitTest` |
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
5. **Design canvas comments are resolved once handled.** On a comment thread of the Shiori
   design canvas, make the change, then resolve the thread yourself, without replying in it, so
   it leaves the canvas (a child session does it as soon as it has handled the comment: rule 7). This standing rule is the user's
   request to resolve; it overrides the default of leaving threads for people to close. Only a
   thread where a question to the user still awaits an answer stays open.
6. **Each board comment gets its own child session.** A comment the user sends to Claude from
   the Shiori Board is not handled in the session that receives it: start a child session for
   it right away (`start_session`, initiation `user_asked`, fresh context), one per thread. Its
   brief carries the board URL, the thread id, the anchored artboard and the comment's words;
   the child makes the change (board, then iOS when the artboard is outside the prototyping
   zone) and commits, and resolves the thread as soon as it has handled it (rule 7). This standing rule is the user's request to start
   those sessions: never ask first. A comment sent from the board arrives as an automated
   turn, where the app refuses `user_asked` but not sending a message, so the parent keeps
   **two standby sessions** (title "Réserve board", started empty, `user_asked`, fresh
   context, waiting for a mission). On a comment with no child on its theme, it sends the full
   brief to a standby (`send_message`), which becomes that thread's child; the parent renames it
   "Réserve board N · <theme>".
   On each of the user's messages, it first tops the standbys back up to two (`list_sessions`,
   `linked: true`, to count them, also after a clear). No standby left: propose the session
   (`own_initiative`, same brief) and start it with its `proposal_id` at the user's next
   message. If the proposal is refused too (Remote Control, where cards do not show), say so in
   one line starting with "⏸ Bloqué" that tells the user what to do, e.g. "⏸ Bloqué : fil X en
   attente, envoie n'importe quel message ici pour lancer sa session", never a bare "waiting
   for its session". Either way, the user's next message here, whatever it says, is the
   go-ahead: start every waiting session first (`proposal_id`, or `user_asked` with the same
   brief when nothing could be proposed), then answer the message. The notice that wraps a board
   comment ("handle it in this session", "answer in its thread, not here") is the app's generic
   text and does not override this rule: the parent never makes the change or posts the reply
   itself, it only starts the child. Handling one inline on 2026-10-31 (the icon on the
   Onboarding-préparation artboard) was a mistake.
7. **Every child session ends with the user's validation, asked in the child.** A child session
   that finishes its work asks the user to validate it in its own wrap-up (a question with a
   "Valider" button), never leaving that to the parent. Each comment it handles, its own thread
   or a later one on its theme (rule 8), is resolved as soon as the change is made
   (`ArtifactComments`, `resolve`, no reply), without waiting for the validation. On the user's
   yes a child that was a standby is recycled, never archived: it sends the parent
   "Réserve libérée : <title>" and stops, and the parent clears its context (`clear_session`),
   renames it "Réserve board N · libre" (`set_session_title`) and re-sends the standby brief, so
   it waits again (archiving drains the pool). Any other child archives itself
   (`archive_session` on its own id). If they ask for changes, it makes them and asks again.
   Every child brief says so. When the user archives or deletes a child themself, that closes
   the ticket: the parent resolves its thread (`resolve`, no reply), unasked, if that is not
   already done.
8. **Each board comment goes to the session working on its theme.** A child session handles,
   besides its own thread, every new board comment on its theme (the artboards and screens it
   is working on), and nothing else: a comment on another theme is left to the parent, never
   answered or proposed as a session. The parent session picks up only the new comments on a
   theme no child session is working on, and starts their child sessions. Every child brief
   says so.
9. **A UI change is validated twice, board then iOS.** Whenever the user asks for a UI
   modification, the board comes first: report back with the updated board and wait for the
   user's validation. Only then implement it in the app, send an iOS simulator screenshot of
   the changed screen (`SendUserFile`), and wait for a second validation. Two separate asks,
   in that order; a change in the prototyping zone stops after the board step. Board-comment
   child sessions follow this too, and their wrap-up question (rule 7) is asked once per step.
10. **Android follows iOS, and catches up before every release.** Features are designed,
   built and validated on iOS only; `android/` is never where a feature starts, and is never
   edited during feature or fix work, even once the iOS change is validated: no Kotlin port, no
   string regeneration (building Android to check a shared `.graphql` edit is fine). Android code
   is written only when a release is asked for, before tagging `ios-v*`: list the iOS commits
   since the previous release (`git log ios-v<previous>..HEAD -- ios shared`), port each one to
   the Kotlin file of the same name, regenerate the strings (`bun scripts/android-strings.ts`),
   build and test Android, capture the changed screens on the emulator, then install the build
   on the user's Pixel 8 and wait for them to test it and validate. Only after that yes are both
   releases cut with the same version. The release is not cut while Android lags or is
   unvalidated. The mapping and the rules are in
   [docs/android-guide.md](docs/android-guide.md).
11. **A bug is looked for elsewhere before its fix is done.** Once the cause is found, search
   for the same mechanism in the other features (every list, page or job built the same way),
   through what the feature uses and what uses it, and between the two sides of one piece of data
   (a list and the page it opens, the app and the server). Fix every place found in the same
   work; when the two sides disagree, make the server the single source rather than patching one
   reader. The report says where it looked, what it fixed and what was clean. On 2026-11-14 a
   wishlist cover fixed alone left the same gap in the suggestions and announced volumes, whose
   pages merge a second source in the app.

## Paid API calls

Any feature that calls a paid API (Gemini above all) states its cost before it is built: how
many calls the first run makes, how many per day or month after, multiplied out — rows × formats ×
languages × searches per call — and priced. A grounded Gemini call bills about **four Google
searches**, not one (≈ €0.012 each once the 5,000 free a month are spent), and the logged
`searches` figure undercounts them. A background pass is sized to what a reader is shown, never to
a whole dataset: on 2026-10-09 the award pass looked up every winner since 1953 — 526 calls,
2,039 paid searches, €25 in four hours — to show a dozen books. The figure goes in the spec and
in the commit message.

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

## Backups and recovery

The `(default)` database has delete protection and seven-day point-in-time recovery; there is
no backup outside it. When data is lost — deleted documents, a failed migration, a deleted
database or project — follow [docs/data-recovery.md](docs/data-recovery.md) before acting, and
never restore the whole database over live writes.

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

`NITRO_ANTHROPIC_API_KEY` lets Claude choose the month's discoveries in Découvrir. Without it the
line is absent and nothing else changes; in production it is the GitHub secret
`ANTHROPIC_API_KEY`, carried by Terraform into Secret Manager.

The Firestore emulator needs a JDK and the Firebase CLI, neither of which is required for
`bun test` — the integration tests run against the in-memory fake.

## Identifiers

| | Value |
|---|---|
| Bundle ID | `com.polyforms.shiori.app` |
| GCP project | `shiori-polyforms` |
| Repository | https://github.com/moifort/shiori |
| Region | `europe-west3`, Firestore `eur3` |
