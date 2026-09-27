# Deprecation routine and forced update — design

Shiori's GraphQL schema is not versioned. A field the app stops using is deprecated, kept
working while older builds are still installed, then removed — and the builds that still ask
for it are sent to the App Store by the update screen that already exists. This spec turns that
into a routine: one command says what can go, one commit removes it and raises the floor, and
CI refuses the two mistakes that would break a reader.

It replaces the stance inherited from Vinarium ("no `@deprecated`, raise the floor on a breaking
change and accept that old builds are blocked while the release is in review"): here a floor
is only ever raised to a build that has been on the App Store for two weeks, so nobody is
blocked without an update already waiting for them.

## What already exists, and stays

| Piece | File |
|---|---|
| Build floor and App Store URL | `server/system/app-support.ts` (`MINIMUM_SUPPORTED_IOS_BUILD`, today `1`) |
| Public config route | `server/routes/app-config.get.ts`, whitelisted in `server/middleware/auth.ts` |
| Launch and foreground check, fail-open | `ios/Shiori/Shared/Services/AppSupportGate.swift` |
| Blocking screen | `ios/Shiori/Shared/Components/UpdateRequiredView.swift`, wired in `AuthRoot.swift` |

The comparison key is `CFBundleVersion`, which CI sets to `git rev-list --count HEAD`: a build
number names a commit and only grows, nightly or App Store alike. The screen cannot be
dismissed; its only action opens the App Store listing.

The gate must be in the first build that reaches the App Store — a build shipped without it
can never be made to update. It is already there.

## Changes to the gate

- **Debug builds skip the check.** A build from Xcode or `scripts/install-device.sh` is a Debug
  build whose `CFBundleVersion` is `1`; the first raised floor would lock the developer out.
  `AppSupportGate.check()` returns at once under `#if DEBUG`. TestFlight and App Store builds
  are Release builds and keep the check.
- **The dangling runbook reference is fixed.** `app-support.ts` points to
  `docs/api-evolution.md`, which Shiori never had. That file is written (see below) and the
  comment on the constant is rewritten to match this routine: the floor is raised by the
  removal commit, to the value `bun run deprecations` proposes, never by hand-counting commits.

## The routine

### 1. Deprecate, in the commit where the app stops asking

In one commit: the iOS operations (`ios/**/*.graphql`) stop selecting the field, argument or
input field, and the server marks it `@deprecated(reason: "…")` (Pothos `deprecationReason`),
naming what replaces it. The resolver keeps working. Nothing records a build number by hand:
the build that stopped asking is derived from git in step 2.

### 2. Ask what can go: `bun run deprecations`

A Bun script, `scripts/deprecations.ts`, prints one row per deprecated element of
`shared/schema.graphql`:

```
element                          no longer asked since   status
Dashboard.pagesPerDay            build 1412              removable
Query.libraryPage(rated:)        build 1437              in grace until 2026-11-03
Book.legacyCover                 —                       still asked by the app
Proposed MINIMUM_SUPPORTED_IOS_BUILD: 1412 (today 1)
```

How it decides, for each deprecated element:

- **Still asked?** The iOS operations at `HEAD` are parsed with `graphql-js` against the schema
  and walked with `TypeInfo`, so a usage is matched on its exact coordinate (`Type.field`,
  `Type.field(arg:)`, `Input.field`) — two types that share a field name are never confused.
  If an operation still uses it: **still asked by the app**, nothing else to compute.
- **No longer asked since which build?** Walking back through the commits that touched
  `ios/**/*.graphql` (`git log --format=%H -- 'ios/**/*.graphql'`), newest first, the script
  parses each commit's operations (`git show <sha>:<path>`) against the schema until it finds
  one that still used the element. The commit after it is the one that stopped; its build is
  `git rev-list --count <that commit>`. An element no build ever used gets build `0`.
- **Is that build on the App Store, and since when?** The script reads, through the App Store
  Connect API (team key, as `scripts/testflight.ts` does), the build of the app version in
  `READY_FOR_SALE`, and takes the date of the `ios-v<marketing>` tag of that version as the
  day it was released.
  - live build ≥ the element's build, and tag date + **14 days** ≤ today: **removable**;
  - live build ≥ the element's build, but inside the fourteen days: **in grace until
    `<date>`**;
  - otherwise: **waiting for a release**.
- **Anything it cannot place** — a deprecated enum value, a directive argument — is listed as
  **check by hand**, with no build number. Removing a value from an output enum is harmless to
  old builds (they read unknown values leniently); an input enum value is for a person to judge.

The proposed floor is the highest build among the removable elements, or the current floor if
none is removable. The script never proposes lowering it.

Without App Store Connect credentials in the environment (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_P8` or `ASC_KEY_PATH`), the script still prints the "no longer asked since" column and
marks every status **unknown (no App Store credentials)** rather than guessing.

### 3. Remove, in one commit

The removable elements go — schema field, resolver, the business code only they used, their
tests — and `MINIMUM_SUPPORTED_IOS_BUILD` takes the proposed value, in the same commit:

```
refactor(api): pagesPerDay and daysToFinish removed, builds below 1412 must update
```

The Deploy workflow ships both together; the next launch or foreground of an older build shows
the update screen.

### When

At every App Store release, the only moment the live build moves: the step that writes the
changelog also runs `bun run deprecations` and removes what it reports as removable — or, since
the grace period ends two weeks later, at the first release after that. `CLAUDE.md` gains this
step in its Workflow section and a pointer to `docs/api-evolution.md`.

## CI guards

Both run in a new `schema.yml` workflow on every push to `main`, alongside the test workflows,
and both are also runnable locally so a failure is never first seen in CI:

- **No breaking change without deprecation.** `bun run schema:check` runs
  `graphql-inspector diff` between the schema at the push's base (`github.event.before`; locally,
  `origin/main`) and `shared/schema.graphql`, with the rule `suppressRemovalOfDeprecatedField`.
  Removing a field that was deprecated in the base passes; removing or renaming a live field,
  changing a type, making an argument required fails the run. `schema:check` joins the pre-commit
  verification list in `CLAUDE.md`.
- **The floor never outruns the App Store.** `bun scripts/deprecations.ts check-floor` fails if
  `MINIMUM_SUPPORTED_IOS_BUILD` is greater than the live App Store build — a reader would be
  blocked with no update to install. While the floor is `1` it passes without calling Apple.
  It runs in `deploy.yml` before the deploy step, so a bad floor never reaches the server.

## Documentation

`docs/api-evolution.md` is written for Shiori: the moving parts table above, the three steps,
the two CI guards, the fail-open rule (an unreachable `/app-config` never blocks the app), and
what counts as breaking. It replaces Vinarium's no-deprecation runbook for this project.

## Out of scope

- Telling the server which build calls it (Apollo's `apollographql-client-version` header) and
  measuring deprecated-field usage per build. The two-week grace plus the update screen make
  the measurement unnecessary; it can come later if a removal ever needs evidence.
- A second, dismissible "update recommended" tier.
- Rejecting too-old builds server-side: the client gate is enough, and a build that slips past
  it (offline check) only meets GraphQL errors until its next foreground.

## Testing

- `scripts/deprecations.ts`: unit tests on the pure parts — locating the coordinates an
  operation uses, choosing the status from (element build, live build, release date, today),
  and proposing the floor — with the git and App Store Connect calls injected.
- `AppSupportGate`: the existing behaviour is unchanged; the Debug skip is a compile-time branch.
- `schema:check`: exercised once by hand against a commit that removes a live field (fails) and
  one that removes a deprecated field (passes), noted in the implementation commit.
