# Shiori 栞

Photograph a book cover. Shiori reads it, looks the book up, and files it — with your rating,
your notes, and the series it belongs to.

> 栞 (*shiori*) is Japanese for a bookmark.

## What it does

- **Scan a cover.** A photo is enough: no barcode to find, no ISBN to type. Works on an old
  edition, a library copy, a book with no barcode at all.
- **Get a real record.** Title, author, publisher, synopsis, genres, first publication year and
  ISBN, filled in from the web and shown to you for approval before anything is saved.
- **Three states, not two.** To read, reading, read. Reading dates follow from moving a book;
  you never type them.
- **Rate and annotate.** Five whole stars and a free-text note.
- **Follow series.** Your books group themselves under the sagas they belong to. Open one and
  you see the whole catalogue — the volumes you own, the ones you are missing, the one
  announced for next year. Nothing enters your library until you add it.
- **Keep some books to yourself.** Every book can be marked as not shared.

## Status

Under construction. The backend domain layer, its GraphQL API and its tests are in place; the
iOS app, the AI scan pipeline and the infrastructure are being built. See
[docs/roadmap.md](docs/roadmap.md).

## Tech stack

**Backend** — TypeScript on [Bun](https://bun.sh), [Nitro](https://nitro.build) deployed to
Cloud Functions gen 2, Apollo Server with [Pothos](https://pothos-graphql.dev) for a code-first
GraphQL schema, Firestore, Firebase Auth (Sign in with Apple), Cloud Storage for covers,
Sentry. Domain-driven design with CQRS, branded types via `ts-brand` and Zod, exhaustive
pattern matching with `ts-pattern`.

**iOS** — SwiftUI on iOS 26, Swift 6 with strict concurrency, Apollo iOS for typed GraphQL
operations.

**AI** — Gemini 2.5 Flash: one vision pass over the cover against a strict response schema,
then a grounded pass that enriches the record from the web, then a third only when a series
needs cataloguing.

**Infrastructure** — Terraform, GitHub Actions, Biome, Renovate.

## Development

```bash
bun install
bun run dev
```

Then open http://localhost:3000/graphql. With `NITRO_DEV_USER_ID` set in `.env` (copy
`.env.example`), Apollo Sandbox works without a Firebase token.

```bash
bunx nitro prepare && bunx tsc --noEmit   # typecheck
bun test                                   # tests
bunx biome check                           # lint
bun run generate:graphql                   # regenerate shared/schema.graphql
```

Conventions and architecture decisions are in [CLAUDE.md](CLAUDE.md).

## License

Not yet licensed.
