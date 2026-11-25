import type { AudibleItem } from 'audible-api-ts'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import {
  audibleLinksFor,
  bookFrom,
  booksFollowed,
  editionYearsFor,
  genresFor,
  heardByAsin,
  heardSagasOf,
  importableFrom,
  itemsToCatalogue,
  listenedMinutesFor,
  listeningChangesFor,
  playbackOf,
  purchaseDatesFor,
  recordingOfVolume,
  seriesVolumesFor,
  shelfOf,
  titlesToFollow,
  volumeBookFrom,
} from '~/domain/audible/business-rules'
import { AudibleCommand } from '~/domain/audible/command'
import * as api from '~/domain/audible/infrastructure/audible-api'
import { openReadableCredentials } from '~/domain/audible/infrastructure/credentials-vault'
import { AudibleQuery } from '~/domain/audible/query'
import type {
  AudibleAsin,
  AudibleDrm,
  AudiblePlayback,
  ImportableBook,
  LibrarySync,
  SyncRun,
} from '~/domain/audible/types'
import { markedRemovedByReader } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage } from '~/domain/book/types'
import { BookUseCase } from '~/domain/book/use-case'
import { watchKeyOf } from '~/domain/discovery/business-rules'
import { DiscoveryCommand } from '~/domain/discovery/command'
import { DiscoveryQuery } from '~/domain/discovery/query'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { SeriesQuery } from '~/domain/series/query'
import type { SagaKey, SeriesName, VolumeNumber } from '~/domain/series/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { openedConnection } from '~/utils/amazon-connection'
import { bulkSave } from '~/utils/firestore'
import { isPresent } from '~/utils/input'
import { NIGHTLY_BUDGET_MS, syncEveryConnectedReader } from '~/utils/nightly-pass'

const logger = createLogger('audible')

export namespace AudibleUseCase {
  /** The reader's Audible library, as books they could catalogue.
   *
   *  Nothing is saved: the answer is a proposal, the same contract `scanBook`
   *  has. The app shows the list, the reader ticks what they want, and
   *  `importAudibleBooks` writes only that. */
  export const importableBooks = async (
    userId: UserId,
  ): Promise<ImportableBook[] | 'not-connected'> => {
    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched
    const owned = await BookQuery.all(userId)
    return toImportable(fetched, owned, await BookQuery.removedAsins(userId, 'audible'))
  }

  /** Catalogue the titles the reader ticked.
   *
   *  The library is fetched again rather than trusted from the app: the client
   *  sends identifiers, and every field that lands in the database comes from
   *  Amazon through the same mapping the preview used. An identifier the reader's
   *  library does not hold simply matches nothing.
   *
   *  Books are written one by one rather than in a batch — a library can run past
   *  the 500-write cap — and the dashboard is marked stale before the first one
   *  lands, so it can never look fresh over books it does not count. Its next
   *  read rebuilds it. */
  export const importBooks = async (
    userId: UserId,
    asins: readonly AudibleAsin[],
  ): Promise<Book[] | 'not-connected'> => {
    const fetched = await fetchLibrary(userId)
    if (fetched === 'not-connected') return fetched

    const wanted = new Set<string>(asins)
    const owned = await BookQuery.all(userId)
    const chosen = toImportable(
      fetched,
      owned,
      await BookQuery.removedAsins(userId, 'audible'),
    ).filter((importable) => wanted.has(importable.asin) && !importable.alreadyInLibrary)

    const imported: Book[] = []
    if (chosen.length > 0) {
      // Each saga named as its catalogue names it, not as Audible titles it.
      const named = await SeriesUseCase.filedAfterCatalogues(chosen.map(bookFrom))
      await AnalyticsUseCase.whileStale(userId, () =>
        bulkSave(named, async (book) => {
          imported.push(await BookCommand.add(userId, book))
        }),
      )
    }
    // Ticked by hand: the reader takes their deletion back.
    await BookCommand.forgetSyncRemovals(
      userId,
      'audible',
      chosen.filter((importable) => importable.removedByReader).map(({ asin }) => asin),
    )
    // The volumes of these sagas the reader does not hold, with their covers,
    // for the saga screen: from Audible now rather than the hourly pass.
    await DiscoveryUseCase.listOnAudible(heardSagasOf([...owned, ...imported]))

    await AudibleCommand.recordImport(userId)
    return imported
  }

  /** One night's pass over a reader's library.
   *
   *  Three things, in an order that matters. Books imported before the ASIN was
   *  kept are linked first, so they take part in the very pass that links them.
   *  Then statuses follow the listening, and books imported before the purchase
   *  date was kept are dated back to it. Then titles bought since the reader last
   *  looked are catalogued — and only those: everything older was on offer when
   *  they last chose what to import, and importing it now would overrule them.
   *
   *  Positions are asked for the titles `titlesToFollow` picks: on the nightly
   *  pass, the books under way and the titles not yet held rather than the
   *  whole library; a pass the reader asked for still asks for every title.
   *
   *  Unlike `importBooks`, this writes books nobody ticked. That is what the
   *  reader asked for by leaving the sync on, and `autoSync` is how they take it
   *  back — except when they asked for this pass themselves, which is what
   *  `onDemand` says. */
  export const syncLibrary = async (
    userId: UserId,
    now = new Date(),
    onDemand = false,
  ): Promise<LibrarySync | 'not-connected' | 'sync-disabled'> => {
    const account = await AudibleQuery.accountOf(userId)
    if (!account) return 'not-connected'
    // Checked before the trip to Amazon: a reader who turned the sync off should
    // cost neither an API call nor a rotated token.
    //
    // `autoSync` governs the nightly pass, not a button. A reader who left it off
    // and then asked for a pass themselves means it, so `onDemand` walks past the
    // switch rather than reporting a setting back at them.
    if (!onDemand && account.autoSync === false) return 'sync-disabled'

    // The shelf first: it decides which titles' positions are worth a call.
    const [owned, removals] = await Promise.all([
      BookQuery.all(userId),
      BookQuery.syncRemovals(userId, 'audible'),
    ])
    const fetched = await fetchLibrary(userId, (items) => titlesToFollow(items, owned, onDemand))
    if (fetched === 'not-connected') return fetched
    const { items, positions, followed } = fetched

    const links = audibleLinksFor(owned, items)
    const linked = owned.map((book) => {
      const link = links.find((candidate) => candidate.bookId === book.id)
      return link ? { ...book, audibleAsin: link.audibleAsin } : book
    })
    const moves = listeningChangesFor(booksFollowed(linked, items, followed), items, positions)
    const listened = listenedMinutesFor(linked, positions)
    const redates = purchaseDatesFor(linked, items)
    const renumbers = seriesVolumesFor(linked, items)
    const editionYears = editionYearsFor(linked, items)
    const genres = genresFor(linked, items)
    // A title whose book the reader deleted stays out, unless they listened to
    // it since: then it comes back, and the deletion is forgotten.
    const wanted = itemsToCatalogue(items, account.lastImportedAt, removals, positions)
    const removed = new Set<string>(removals.map(({ asin }) => asin))
    const returning = wanted.filter((item) => removed.has(item.asin)).map(({ asin }) => asin)
    const bought = toImportable({ items: wanted, positions }, linked).filter(
      (importable) => !importable.alreadyInLibrary,
    )

    const changed =
      links.length +
      moves.length +
      listened.length +
      redates.length +
      renumbers.length +
      editionYears.length +
      genres.length +
      bought.length
    const added: Book[] = []
    const write = async () => {
      await bulkSave(links, async (link) =>
        BookCommand.linkToAudible(userId, link.bookId, link.audibleAsin),
      )
      // Audible's own finishing date, not tonight's: a title finished last spring
      // that the sync only hears about now must not land on today and rewrite the
      // reading statistics, for the same reason an import does not.
      await bulkSave(moves, async (move) =>
        BookCommand.setStatus(userId, move.bookId, move.status, move.at ?? now),
      )
      // Where the player got to, which the dashboard and the book read the
      // listening progress off, and when, which files a recording under way.
      await bulkSave(listened, async ({ bookId, ...position }) =>
        BookCommand.recordListening(userId, bookId, position, now),
      )
      // Books imported before the purchase date was kept all sit on import night;
      // this is what files them under the month they were in fact bought.
      await bulkSave(redates, async ({ bookId, ...dates }) =>
        BookCommand.backdate(userId, bookId, dates, now),
      )
      // Split novels imported before their parts were numbered sit in their
      // saga without a rank; this is what puts them on the volume they are.
      await bulkSave(renumbers, async ({ bookId, volume }) =>
        BookCommand.numberInSeries(userId, bookId, volume, now),
      )
      // Audiobooks imported before the edition year was kept show none; this is
      // what gives them the year their recording came out.
      await bulkSave(editionYears, async ({ bookId, editionYear }) =>
        BookCommand.edit(userId, bookId, { editionYear }, now),
      )
      // Audiobooks imported from a store whose shelves were not yet known carry
      // no genre; this is what files them once it is, each on its own: the
      // other volumes of its saga keep the genre they have.
      await bulkSave(genres, async ({ bookId, genre }) =>
        BookCommand.fillGenre(userId, bookId, genre, now),
      )
      await bulkSave(
        await SeriesUseCase.filedAfterCatalogues(bought.map(bookFrom)),
        async (book) => {
          added.push(await BookCommand.add(userId, book, now))
        },
      )
    }
    // A night with nothing new leaves the dashboard as it was.
    if (changed > 0) await AnalyticsUseCase.whileStale(userId, write)
    await BookCommand.forgetSyncRemovals(userId, 'audible', returning)
    // Every night, not only on a new title: a library imported before the
    // sagas heard were listed from Audible is listed over the next nights.
    await DiscoveryUseCase.listOnAudible(heardSagasOf([...linked, ...added]), now)

    await AudibleCommand.recordImport(userId, now)
    return {
      linked: links.length,
      moved: moves.length,
      imported: bought.length,
      redated: redates.length,
      renumbered: renumbers.length,
      editionDated: editionYears.length,
      genred: genres.length,
    }
  }

  /** A volume of a saga heard, added from its saga screen with Audible's own
   *  data — cover, summary, narrators, running time — read through the
   *  reader's account, on the store they buy on, whether or not they own the
   *  recording yet. The one the weekly release watch confirmed is read by its
   *  ASIN; otherwise the store is searched for the saga, and the recording in
   *  the edition's language at the volume's place is kept.
   *
   *  `not-found` when the saga has no catalogue or no such volume, or when
   *  Audible sells no recording of it there. */
  export const addSeriesVolume = async (
    userId: UserId,
    { saga, volume, language }: { saga: SagaKey; volume: VolumeNumber; language: BookLanguage },
  ): Promise<Book | 'not-connected' | 'not-found'> => {
    const connected = await connectedCredentials(userId)
    if (connected === 'not-connected') return connected
    const [catalogue, watches] = await Promise.all([
      SeriesQuery.byId({ saga, language }),
      DiscoveryQuery.watches([watchKeyOf({ seriesId: saga, language })]),
    ])
    const entry = catalogue?.volumes.find(
      (candidate) => candidate.kind === 'main' && candidate.number === volume,
    )
    if (!catalogue || !entry) return 'not-found'
    const confirmed = watches
      .get(watchKeyOf({ seriesId: saga, language }))
      ?.volumes.find((found) => found.number === volume)?.asin

    const { recording, credentials } = await recordingOf(connected.credentials, {
      saga,
      volume,
      language,
      asin: confirmed,
      name: catalogue.name,
      author: catalogue.author,
      title: entry.titles?.[language] ?? entry.title,
    })
    await AudibleCommand.rememberRotatedCredentials(userId, credentials)
    if (!recording) return 'not-found'

    const membership = { saga, name: catalogue.name, volume, kind: 'main' as const }
    return BookUseCase.add(userId, volumeBookFrom(recording, membership, language))
  }

  /** What the app's player needs to play one title: a licence in the DRM of
   *  the reader's device (FairPlay unless told Widevine), asked of Amazon when
   *  the reader presses play and never ahead — Amazon counts the licences a
   *  device takes.
   *
   *  `denied` when Amazon grants none: a title the account does not own, or a
   *  device past its licence quota.
   *
   *  `offline` asks for a download licence: the same stream, whose key the
   *  device may keep, so the title plays with no network once downloaded. */
  export const playback = async (
    userId: UserId,
    asin: AudibleAsin,
    { offline = false, drm = 'fairplay' }: { offline?: boolean; drm?: AudibleDrm } = {},
  ): Promise<AudiblePlayback | 'not-connected' | 'denied'> =>
    withCredentials<AudiblePlayback | 'denied'>(userId, async (credentials) => {
      try {
        const { license, credentials: rotated } = await api.playbackLicense(credentials, asin, {
          consumption: consumptionOf(offline),
          drm: drmTypeOf(drm),
        })
        return { value: playbackOf(asin, license), credentials: rotated }
      } catch (error) {
        if (!(error instanceof api.LicenseDeniedError)) throw error
        // Audible's own reasons can name the customer: the status is enough to
        // tell a quota from an ownership refusal.
        logger.warn('Audible licence denied', { status: error.status, asin, drm })
        return { value: 'denied' as const, credentials }
      }
    })

  /** Trade the player's FairPlay key request for the content key. Relayed
   *  rather than asked by the app: the call is signed with the device
   *  credentials, which never leave the server. `offline` asks for a key the
   *  device may keep, for a title played from a download licence. */
  export const fairPlayKey = async (
    userId: UserId,
    asin: AudibleAsin,
    spc: string,
    { offline = false }: { offline?: boolean } = {},
  ): Promise<string | 'not-connected'> =>
    withCredentials(userId, async (credentials) => {
      const { ckc, credentials: rotated } = await api.fairPlayKey(credentials, asin, spc, {
        consumption: consumptionOf(offline),
      })
      return { value: ckc, credentials: rotated }
    })

  /** Answer a Widevine key request from Android's player with Amazon's
   *  licence. Relayed for the same reason as `fairPlayKey`, with the same
   *  `offline`. */
  export const widevineKey = async (
    userId: UserId,
    asin: AudibleAsin,
    challenge: string,
    { offline = false }: { offline?: boolean } = {},
  ): Promise<string | 'not-connected'> =>
    withCredentials(userId, async (credentials) => {
      const { license, credentials: rotated } = await api.widevineKey(
        credentials,
        asin,
        challenge,
        { consumption: consumptionOf(offline) },
      )
      return { value: license, credentials: rotated }
    })

  /** Save where the reader stopped, on Audible itself: their other players —
   *  the Audible app, an Echo — resume there, and so does the nightly sync. */
  export const savePosition = async (
    userId: UserId,
    position: { asin: AudibleAsin; contentReference: string; positionMs: number },
  ): Promise<'saved' | 'not-connected'> =>
    withCredentials(userId, async (credentials) => {
      const { credentials: rotated } = await api.savePosition(credentials, {
        asin: position.asin,
        acr: position.contentReference,
        positionMs: position.positionMs,
      })
      return { value: 'saved' as const, credentials: rotated }
    })

  /** The nightly job: every reader who left the sync on, stalest first. See
   *  `syncEveryConnectedReader`. */
  export const syncEveryReader = async (
    budgetMs = NIGHTLY_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<SyncRun> =>
    // Subscribers only: there is no free plan, and an account without Premium waits behind
    // the offer, its library kept as it was.
    syncEveryConnectedReader(
      await EntitlementQuery.subscribersAmong(await AudibleQuery.readersToSync()),
      {
        syncLibrary: (userId) => syncLibrary(userId),
        // Outside any request: their Découvrir projections are told here.
        afterSync: (userId) => DiscoveryCommand.recordLibraryChange([userId]),
        logger,
        budgetMs,
        startedAt,
      },
    )
}

/** One trip to Amazon, with the rotated access token written back.
 *
 *  The client refreshes an expired token on its own and hands the new
 *  credentials back; storing them is what keeps the next import from paying for
 *  that refresh again. */
const fetchLibrary = async (
  userId: UserId,
  follow: (items: readonly AudibleItem[]) => string[] = (items) => items.map(({ asin }) => asin),
) => {
  const connected = await connectedCredentials(userId)
  if (connected === 'not-connected') return connected
  const { account, credentials } = connected

  const { items, credentials: rotated } = await api.library(credentials)
  // Where the player last stopped in the titles `follow` picks, every one of
  // them by default, in one pass: the library's own percentage is stale, and
  // this is what decides which titles are being read. Both trips can rotate
  // the token; the last word is what is kept.
  const followed = follow(items)
  const { positions, credentials: rotatedAgain } = await api.lastPositions(rotated, followed)
  await AudibleCommand.rememberRotatedCredentials(userId, rotatedAgain)
  return { items, positions, followed, account }
}

/** One call to Amazon with the reader's opened credentials, the rotated access
 *  token written back only when it did rotate: a playing title saves its
 *  position every half minute, and a write each time would be a write for
 *  nothing. */
const withCredentials = async <T>(
  userId: UserId,
  call: (credentials: Credentials) => Promise<{ value: T; credentials: Credentials }>,
): Promise<T | 'not-connected'> => {
  const connected = await connectedCredentials(userId)
  if (connected === 'not-connected') return connected
  const { value, credentials } = await call(connected.credentials)
  if (credentials.accessToken !== connected.credentials.accessToken) {
    await AudibleCommand.rememberRotatedCredentials(userId, credentials)
  }
  return value
}

/** The reader's account and its credentials, opened: see `openedConnection`. */
const connectedCredentials = (userId: UserId) =>
  openedConnection(userId, {
    accountOf: AudibleQuery.accountOf,
    openIfReadable: openReadableCredentials,
    disconnect: AudibleCommand.disconnect,
    logger,
  })

const toImportable = (
  fetched: {
    items: Awaited<ReturnType<typeof api.library>>['items']
    positions: Awaited<ReturnType<typeof api.lastPositions>>['positions']
  },
  owned: readonly Book[],
  removed: ReadonlySet<string> = new Set(),
): ImportableBook[] => {
  const shelf = shelfOf(owned)
  const heard = heardByAsin(fetched.positions)
  return markedRemovedByReader(
    fetched.items
      .map((item) => importableFrom(item, shelf, heard.get(item.asin)))
      .filter(isPresent),
    removed,
  )
}

type Credentials = Parameters<typeof api.search>[0]

/** Every candidate turned into what it would be catalogued as, to be matched
 *  on its language and its place in the saga. Nothing is owned here. */
const importablesOf = (items: readonly AudibleItem[]) =>
  items.map((item) => importableFrom(item, new Map())).filter(isPresent)

/** The recording of one volume on the reader's store: by the ASIN the release
 *  watch confirmed, then among the saga's recordings, then among a search for
 *  the volume's own title — each step only when the one before found nothing. */
const recordingOf = async (
  credentials: Credentials,
  wanted: {
    saga: SagaKey
    volume: VolumeNumber
    language: BookLanguage
    asin?: AudibleAsin
    name: SeriesName
    author: AuthorName
    title: BookTitle
  },
): Promise<{ recording?: ImportableBook; credentials: Credentials }> => {
  let current = credentials
  if (wanted.asin) {
    const { item, credentials: rotated } = await api.product(current, wanted.asin)
    current = rotated
    const [recording] = importablesOf(item ? [item] : [])
    if (recording) return { recording, credentials: current }
  }
  const searches = [
    { title: wanted.name, author: wanted.author, limit: 50 },
    { keywords: wanted.title, author: wanted.author, limit: 20 },
  ]
  for (const options of searches) {
    const { items, credentials: rotated } = await api.search(current, options)
    current = rotated
    const recording = recordingOfVolume(importablesOf(items), wanted)
    if (recording) return { recording, credentials: current }
  }
  return { credentials: current }
}

/** How Audible is asked to license a title: kept on the device, or streamed. */
/** The reader's DRM as Audible names it. */
const drmTypeOf = (drm: AudibleDrm) => (drm === 'widevine' ? 'Widevine' : 'FairPlay')

const consumptionOf = (offline: boolean) =>
  offline ? ('Download' as const) : ('Streaming' as const)
