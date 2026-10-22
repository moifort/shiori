# iOS Guide

How the Shiori app is built: where a file goes, what a view may do, how a screen loads, pages,
caches and refreshes, and how it is checked. Transposed from Vinarium's `docs/ios-guide.md`,
then narrowed where Shiori decided differently.

The rules here are the target. Code written before them still diverges (see
[Known divergences](#known-divergences)); new code follows the guide, and a screen is brought
in line when it is next touched, one domain at a time — never a big-bang rewrite.

## Stack

- **SwiftUI**, iOS 26 deployment target, **Swift 6** strict concurrency
- **Apollo iOS** — typed GraphQL operations, generated into `Generated/GraphQL/` (never edited)
- **Firebase Auth** (Sign in with Apple), **Sentry**
- Xcode `fileSystemSynchronizedGroups`: a new file is picked up without touching the project

## The one rule

**A view is either pure or connected, and its name says which.**

- **Pure** — receives values and actions, draws them. No API call, no `.task` that fetches, no
  `.shared` singleton, no `NotificationCenter`. Renders in a `#Preview` from fixtures alone.
  Everything under `components/`, `Shared/Components/` and `Shared/Book/` is pure, and
  `scripts/check-ios-components.ts` fails the iOS build when it is not.
- **Connected** — the `{Feature}Screen` at the root of a feature. It owns the ViewModel, the
  `.task`s, the change notices, the navigation and the sheets, and hands values and actions to
  its `Page`. It draws nothing of its own.

Everything else in this guide follows from that line. It is what makes a screen checkable
without a server, and a ViewModel testable without a network.

## Layout

```
ios/Shiori/
├── ShioriApp.swift, ContentView.swift
├── Generated/GraphQL/                 Apollo output, never edited
├── Shared/
│   ├── Components/
│   │   ├── atoms/                     RatingStars, LanguageTag, RibbonMark, AsyncButton…
│   │   ├── molecules/                 LabeledInfoRow, SeriesLinkRow, LoadMoreRow, EmptyState…
│   │   ├── organisms/                 BookCover, BookRow, CoverTile, ShelfMosaic: take a Book
│   │   └── styles/                    label styles, colours, view modifiers
│   ├── Book/                          the book page's parts, shared by every book screen
│   ├── Platform/                      UIKit wrappers: CameraView, CameraPicker, AmazonSignInWebView…
│   ├── Shell/                         the app around the tabs: LaunchCurtain, UpdateRequiredView…
│   └── GraphQLClient.swift, SnapshotCache.swift, CursorPage.swift, DataChanges.swift…
└── Features/{Domain}/                 Discover, Series, Authors, Friends, Library, Book, Scan…
    ├── {Feature}Screen.swift          connected: ViewModel, tasks, navigation, sheets
    ├── {Feature}ViewModel.swift       state + actions, init(client:)
    ├── {Domain}Client.swift           struct of async closures, .live and .preview
    ├── {Domain}API.swift              GraphQL operations → app models
    ├── {Domain}Models.swift           Sendable app models
    ├── {Domain}Fixtures.swift         preview and test data
    └── components/
        ├── organisms/                 sections, strips, cards, forms
        └── pages/                     a whole screen, pure
```

**Domains follow the business**, not the tabs: a domain owns its models, its API, its client
and its components. A component another domain needs is imported from its domain, not copied.

**Atoms and molecules live only in `Shared/`.** A domain holds organisms and pages. The levels
exist to find a component, not to argue about one: a component small enough to be an atom is
almost always free of business meaning, and then it belongs to the design system. One that
carries business meaning is an organism of its domain.

| Level | Where | Receives | Examples |
|---|---|---|---|
| Atom | `Shared/Components/atoms/` | Primitives | `RatingStars`, `LanguageTag` |
| Molecule | `Shared/Components/molecules/` | Primitives, atoms | `LabeledInfoRow`, `LoadMoreRow` |
| Organism | `Features/{D}/components/organisms/` | An `Item` or a domain model, actions | `AwardWinnersStrip`, `SagaReleasesSummary` |
| Page | `Features/{D}/components/pages/` | Values, bindings, one action handler | `HomePage`, `DiscoverPage` |
| Screen | `Features/{D}/{F}Screen.swift` | Owns the ViewModel | `HomeScreen`, `DiscoverScreen` |

**Platform wrappers** (`UIViewControllerRepresentable` around a camera, a mail composer, a
contact picker, a web view) are not design components: they live in `Shared/Platform/`, and a
page receives what they produce, never the wrapper's own state.

**Naming carries the category.** `Screen` = connected, `Page` = pure whole screen,
`Section` / `Card` / `Strip` / `Row` / `Tile` = organism or molecule. A file named `…View`
says nothing; new files never use it. The UIKit wrappers in `Shared/Platform` are the exception:
they are named after what they wrap (`MailComposeView`, `AmazonSignInWebView`).

**One component per file**, named after it. A reusable view hidden at the bottom of a
600-line screen file is a view nobody finds. A `private` helper view only that file uses may
stay.

## Screen, page, action

```swift
/// Everything Découvrir's page can ask for.
enum DiscoverAction {
    case openVolume(DiscoveryVolume)
    case stopAwaiting(AwaitedEdition)
    case changeAwardsFormat(ReleaseFormat)
    case refresh
}

struct DiscoverPage: View {
    let feed: DiscoveryFeed
    let isLoading: Bool
    let onAction: (DiscoverAction) async -> Void
    // body: draws feed, calls `await onAction(.stopAwaiting(edition))` from an AsyncButton
}

struct DiscoverScreen: View {
    @State private var viewModel = DiscoverViewModel(client: .live)
    @State private var openVolume: DiscoveryVolume?

    var body: some View {
        DiscoverPage(feed: viewModel.feed, isLoading: viewModel.isLoading) { action in
            switch action {
            case let .openVolume(volume): openVolume = volume
            case let .stopAwaiting(edition): await viewModel.stopAwaiting(edition)
            case let .changeAwardsFormat(format): await viewModel.loadAwards(format)
            case .refresh: await viewModel.load()
            }
        }
        .task { await viewModel.loadOnAppear() }
        .sheet(item: $openVolume) { AnnouncedVolumeScreen(volume: $0) }
    }
}
```

- **One `onAction` per page, over an `enum`.** The screen's `switch` is exhaustive: an action
  added to the page and forgotten in the screen does not compile. A page with a dozen
  `var onX: () -> Void = {}` closures compiles with one left unwired and silently does nothing
  — `HomePage`'s sixteen closures are the case this rule exists for.
- An organism with one or two actions takes plain closures; the enum is for pages.
- **An action the page waits on is `async`**, awaited through `AsyncButton` /
  `AsyncToolbarButton`, which draw the progress and disable the control while it runs. A page
  whose actions only open or switch something (`HomePage`, `SettingsHomePage`) takes a plain
  `(Action) -> Void`. A tap on a row of an async page sends `Task { await onAction(…) }`: the
  page starts it, the screen does the work.
- A sheet that asks the server for proposals (a vocabulary, merge candidates) receives an
  async loader — `loadVocabulary: () async -> BookVocabulary?` — rather than the client.
- **Navigation state** (which sheet, which pushed destination) lives in the screen. The page
  only says what was tapped.

## Primitive-first leaves

Atoms and molecules take primitives — `String`, `Int?`, `Date?`, `Bool`, a logic-free enum,
closures — never a domain struct. An organism may take a domain model: it is the mapping
boundary, and the children it draws get primitives. When a component needs more than about
five parameters, it declares a nested `Item` and the screen or the organism builds it.

## ViewModel and client

```swift
struct DiscoverClient: Sendable {
    var feed: @Sendable () async throws -> DiscoveryFeed
    var awards: @Sendable (ReleaseFormat) async throws -> [AwardSection]
    var stopAwaiting: @Sendable (AwaitedEdition.ID) async throws -> Void
}

extension DiscoverClient {
    static let live = DiscoverClient(
        feed: { try await DiscoverAPI.feed() },
        awards: { try await AwardsAPI.sections(format: $0) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) }
    )
    static let preview = DiscoverClient(
        feed: { .preview },
        awards: { _ in AwardSection.previews },
        stopAwaiting: { _ in }
    )
}

@MainActor @Observable
final class DiscoverViewModel {
    init(client: DiscoverClient) { … }
}
```

- **A struct of closures, not a protocol.** No mock class to write: a test builds the client
  it needs inline, overriding one closure.
- The ViewModel is `@MainActor @Observable`, state is `private(set)`, errors go through
  `reportError()`.
- `{Domain}API` stays the only place that touches Apollo types. The client is a thin seam over
  it, so the ViewModel never sees a generated type.
- **Business logic leaves the views.** "Look the book up, then add it" exists once, as a
  client call or a function in the domain, and every screen that adds a book reaches it
  through an action. Formatting a line (`authorLine`, a release date phrase) is a pure function
  on the model, testable without a view.
- **No singleton read in a component.** `PushRegistrar`, the Audible and Kindle background
  syncs, `LibraryPreparation` are read by the screen and passed down as values, or injected
  through `@Environment` by the app.

## Loading

**Every network call shows that it runs**, except a refresh over content already on screen.

- A list or page with nothing yet shows a `ProgressView` in its body, never full screen over
  the chrome.
- A button that triggers a mutation shows its progress and is disabled while it runs
  (`AsyncButton`, `AsyncToolbarButton`).
- The launch shows `LaunchCurtain`, held until `AuthRoot` has something settled behind it.

### Failures

- **Over content already on screen, a failure says nothing.** The rows stay as they were;
  replacing a good library with an empty one because a refresh failed reads as data loss. The
  error is still reported to Sentry.
- **Over an empty screen**, `EmptyState.failure(title, message:, retry:)`.
- **Every screen that loads is pullable**, empty or not: `.refreshable` is the retry.
- A cancellation is not a failure: check `isCancellation(error)` and return.

## Snapshots: screens that reopen on what they showed

A screen that changes slowly and that the reader recognises keeps what it showed last on disk,
through `SnapshotCache<Value>` (`Shared/SnapshotCache.swift`), in the one `snapshots/` folder
of the caches directory.

- **Read synchronously in the ViewModel's `init`**, before any request, so the screen is
  readable on its first frame.
- **Written after each successful load**, off the main actor (`Task.detached { cache.write(…) }`).
- **One file per view and filter** (`library-<mode>-<status>`): switching view shows that
  view's last rows at once, refreshed silently.
- **Never more than the first page** in a file, whatever depth the list was scrolled to.
- **Versioned.** Bump `version` whenever the cached type changes shape; an older file is
  ignored, never decoded into something that no longer means the same thing.
- **The refresh that follows draws nothing**: the answer is assigned inside
  `withAnimation(rows.isEmpty ? nil : .smooth)`, so rows slide in place. A first fill over an
  empty screen is not animated.
- **Cleared** by `SnapshotCaches.clear()` at sign-out and account deletion: the next account
  never reads the previous one's library.
- **Not for data worthless when stale**: a quota, a subscription state, an invitation code.

Screens on snapshots today: Home (dashboard, releases, friends' favourites, discoveries),
Library, Series list, Authors list, Discover (feed, awards, discoveries), Shared, a friend's
profile.

## Covers

`CoverImages` (`Shared/CoverImages.swift`) caches covers in memory and on disk, **keyed by
what the image is, not by its URL**: a photographed cover comes through a URL signed for one
hour, so the key drops the `X-Goog-*` query items.

- Memory holds each cover decoded at the size it is drawn (`maxPixelSize`), capped at 200 MB
  of decoded bytes; disk holds it as served, in `covers/` of the caches directory.
- `cached(_:)` is synchronous, so a row redrawn with a fresh link shows its cover on its first
  frame.
- A download, once started, runs to the end even if its tile scrolls away.
- A list prefetches the covers of each page it loads (`CoverImages.prefetch`).
- Cleared with the snapshots at sign-out.

A cover loaded by URL is the one network read a pure component may do: it draws its
placeholder in a preview, and that is enough.

## Pagination

Long lists — the library, the sagas, the authors, a friend's shelf and sagas — load by pages.

- **Cursor, not offset.** Read `hasMore`, pass the cursor of the last row as `after` — its id,
  or the page's `endCursor` where a row has no single id (a saga row is a saga and an
  edition). A cursor naming a row no longer there restarts from the top. An offset shifts
  under a list that changed between two pages and drops or repeats rows; every list pages by
  cursor, and `CursorPage` carries a page and its cursor to the ViewModel.
- **Page size is sized to the screen, not to the dataset.** Sixty rows fill several screens of
  the list on the smallest phone; the mosaic shows some seventy covers a screen, so its page is
  140. The server caps a page (200 for the library).
- **Prefetch before the end.** The row `prefetchThreshold` from the end starts the next page
  (`onPrefetch(id)` → `prefetchIfNeeded(for:)`): 8 rows in a list, 42 covers in the mosaic.
  Well below the page size, or the next page loads as soon as the first is shown.
- **`LoadMoreRow`** closes the list while `hasMore`: a spinner that loads on appear, and a
  "Réessayer" button once a page failed, otherwise the spinner would turn forever.
- **A generation token** guards every load: a page asked for before a reload is dropped
  rather than appended to the list that replaced it. A new view or filter cancels the reload in
  flight, shows that view's snapshot, and loads its first page.
- **Reload keeping depth.** After an edit on page three, `load(keepingDepth: true)` fetches as
  many rows as are shown, in as many capped pages as needed, swapped in at once so the list
  never shrinks in between and the reader stays where they were.
- **Patch rather than reload** when the write named one row (see below): `apply(book)` puts the
  row back where the server would now shelve it, or drops it when it no longer belongs to the
  view; a row shelved past the last loaded one waits for its page.

## Change notices

Every mutation goes through `GraphQLHelpers.perform`, which posts `.shioriDataDidChange` once
the write landed — so no screen has to remember to.

- One notice for everything: lists are cheap to refetch, and naming what changed for each
  screen to decide whether it cares is where stale rows come from.
- A write to one book or one saga carries a `DataChange` (`.book(id:)`, `.series(id:)`) as the
  object, so a list can patch that row instead of reloading.
- A mutation that cannot change the library passes `changesLibrary: false`.
- **Only screens listen.** A page or organism never subscribes; the screen reloads its
  ViewModel and the page redraws.
- `loadOnAppear()` asks nothing once the server has answered: coming back to a tab redraws
  nothing new, the notices already did.

## Previews and fixtures

**Every view has a `#Preview`**: atoms, molecules, organisms, pages. Preview names are
English; the copy inside is French like the app's.

- Fixtures sit beside their type as `static let preview` (`Dashboard.preview`,
  `AwaitedEdition.preview`, `SagaDiscovery.preview`), or in `{Domain}Fixtures.swift` when there
  are several. Tests reuse them.
- A page gets one preview per state that matters: filled, empty, loading, failed, first use.
- A screen's preview is a smoke preview at best: it is where nothing is designed.
- **A view that resists previewing is a design smell**: pull the pure part out (as
  `FriendBookPage` was out of `FriendBookView`) rather than skip the preview. The one accepted
  exception is a view built on a StoreKit `Product`, which has no public initializer.
- To screenshot a screen with data, feed its page the committed fixtures through the
  launch-argument harness in `ShioriApp.swift`, or launch with `-showcase` (the App Store
  fixtures, no sign-in). Revert the harness; keep the fixtures and previews.

## Tests

Previews check how a view looks; unit tests check what the app decides. They do not overlap.

- **What is tested**: ViewModels with a fake client — the state after a load, after a failure
  over rows and over nothing, a stale page dropped by the generation token, `apply(book)`
  placing or dropping a row, `keepingDepth` fetching enough pages; and the pure functions on
  models (ordering, sectioning, formatting).
- **What is not**: a SwiftUI `body`. A test that inspects a view hierarchy breaks on every
  layout tweak and proves nothing a preview does not show better.
- A test needs no network, no Firebase, no simulator state: the client is built inline, the
  data comes from the fixtures. A cached ViewModel takes `caching: false` (Discover's
  `snapshots: .none`), so a test neither reads nor leaves a snapshot on disk.
- The doubles every test shares — `Boom`, `Flag`, `Calls` — are in `ShioriTests/Support/`.
- The Build workflow runs `ShioriTests` on every push.
- `ShioriUITests` keeps the end-to-end screenshots; it is not where logic is tested.

## Design conventions

- **Book pages look alike.** A screen showing a book (announced, awaited, suggested, a
  friend's) composes the shared book parts: the read-only header, `LabeledInfoRow` for facts,
  the orange "Sort en…" banner. Only known fields are drawn. Never a bespoke layout.
- **Colours that mean something**: an upcoming or announced date is orange, an available one
  green. A destructive button's icon is red too — with `.labelStyle(.row)` it stays accent
  blue unless coloured.
- **Icons beside a title and description sit at the top** (`HStack(alignment: .top)`), never
  centred.
- **No hint text under sections** — no `footer:` caption explaining a picker. A message that
  matters in one state is a row inside the section, shown only in that state.
- **Toolbar actions are icon-only**, through `ToolbarIconButton` and `AsyncToolbarButton`;
  the title is kept for VoiceOver. Cancel `xmark` on the left, confirm `checkmark` on the right.
  A text-only item never moves into the iPhone Duo's vertical bar. Close or cancel is
  `.cancellationAction`, confirm is `.confirmingAction` (pinned trailing from iOS 27, so it
  heads the Duo's vertical bar and never overflows).
- **A tappable row answers on its whole width**: a `.plain` `Button` whose label carries
  `.contentShape(.rect)`, set in the row view so every caller inherits it. Never
  `onTapGesture` in place of a button.

## Localisation

Strings are written in French in Swift and are the catalogue keys (`sourceLanguage: fr`); the
development language is English, the fallback for every other iPhone language. Every key needs
an explicit `fr` unit, or a French iPhone falls back to English. After any on-screen text
change: build, then `bun scripts/check-strings.ts <derived-data> --write`, fill the English,
and commit the catalogue with the UI. CI runs the same check without `--write`.

## GraphQL

- `{Domain}API` enums wrap the generated operations and return app models.
- After a schema change: `bun run generate:graphql`, then `apollo-ios-cli generate` from
  `ios/`.
- The schema is not versioned: a field the app stops using is deprecated, never removed in the
  same change ([api-evolution.md](api-evolution.md)).

## Build

```bash
xcodebuild -project ios/Shiori.xcodeproj -scheme Shiori \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' build
```

A build into a fresh `-derivedDataPath` needs `SWIFT_ENABLE_EXPLICIT_MODULES=NO` (else
`import Sentry` fails on CoreTelephony). A fresh worktree also lacks the gitignored
`Generated/GraphQL/*`, `Secrets.swift`, `GoogleService-Info.plist` and `Package.resolved`:
copy them from the main checkout. Never clear the build cache to unblock a broken build.

## Known divergences

What is left, as of 2026-10-15, once every domain and the leftovers were brought in line:

- **App-level services** still read their APIs directly — `OnboardingGate`,
  `SubscriptionStore`, `PushRegistrar`, the Audible and Kindle background syncs. They are not
  views; a client for them waits until they need tests.
