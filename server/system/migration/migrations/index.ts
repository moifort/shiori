import { heartsAreFiveStars } from '~/system/migration/migrations/004-hearts-are-five-stars'
import { booksCarryTheirShelfDate } from '~/system/migration/migrations/005-books-carry-their-shelf-date'
import { discoverIsTranslations } from '~/system/migration/migrations/006-discover-is-translations'
import { discoverIsReleases } from '~/system/migration/migrations/007-discover-is-releases'
import { audiobooksJoinTheSagaHeard } from '~/system/migration/migrations/008-audiobooks-join-the-saga-heard'
import { discoveryReplacesDiscover } from '~/system/migration/migrations/009-discovery-replaces-discover'
import { booksCarryTheirSagaName } from '~/system/migration/migrations/010-books-carry-their-saga-name'
import { watchesOlderThanTheirCatalogue } from '~/system/migration/migrations/011-watches-older-than-their-catalogue'
import { digestAlertStartsOn } from '~/system/migration/migrations/012-digest-alert-starts-on'
import { cataloguesPerEdition } from '~/system/migration/migrations/013-catalogues-per-edition'
import { paperAndScreenAreOneBook } from '~/system/migration/migrations/014-paper-and-screen-are-one-book'
import { booksWithoutALanguageAreFrench } from '~/system/migration/migrations/015-books-without-a-language-are-french'
import { cataloguesWithoutALanguageAreFrench } from '~/system/migration/migrations/016-catalogues-without-a-language-are-french'
import { cataloguesRenumberedByTheWatch } from '~/system/migration/migrations/017-catalogues-renumbered-by-the-watch'
import { titlesWithoutTheirSaga } from '~/system/migration/migrations/018-titles-without-their-saga'
import { alertsNoDeviceHeard } from '~/system/migration/migrations/019-alerts-no-device-heard'
import { volumesNumberedThroughTheirSaga } from '~/system/migration/migrations/020-volumes-numbered-through-their-saga'
import { cataloguesUnderTheAuthorReversed } from '~/system/migration/migrations/021-catalogues-under-the-author-reversed'
import type { Migration } from '~/system/migration/types'

// Forward-only, sequential, no rollback. Adding a new optional field or a new
// collection needs no migration — only renaming, restructuring, or removing
// stale data does.
//
// Numbering resumed at 4 after the database was reset: `migration-meta` in
// production records version 2, or 3, left by the migrations this list held
// before, and the runner skips any version at or below the one recorded.
export const migrations: Migration[] = [
  heartsAreFiveStars,
  booksCarryTheirShelfDate,
  discoverIsTranslations,
  discoverIsReleases,
  audiobooksJoinTheSagaHeard,
  discoveryReplacesDiscover,
  booksCarryTheirSagaName,
  watchesOlderThanTheirCatalogue,
  digestAlertStartsOn,
  cataloguesPerEdition,
  paperAndScreenAreOneBook,
  booksWithoutALanguageAreFrench,
  cataloguesWithoutALanguageAreFrench,
  cataloguesRenumberedByTheWatch,
  titlesWithoutTheirSaga,
  alertsNoDeviceHeard,
  volumesNumberedThroughTheirSaga,
  cataloguesUnderTheAuthorReversed,
]
