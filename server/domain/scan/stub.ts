import { CoverUrl, Genre, Isbn13, PageCount, Publisher, Synopsis } from '~/domain/book/primitives'
import type { ScanResult } from '~/domain/scan/types'
import { SeriesName, seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

/** What a stubbed scan answers. A complete book on purpose: the review screen
 *  shows every field, so a partial one would leave the end-to-end scenario blind
 *  to half of it. It carries a series so the grouping and the catalogue path are
 *  exercised too.
 *
 *  Only ever reached under `import.meta.dev`, so this module is tree-shaken out
 *  of a production bundle along with the branch that reads it.
 */
export const STUBBED_SCAN: ScanResult = {
  recognized: true,
  title: BookTitle('Le Nom du vent'),
  authors: [AuthorName('Patrick Rothfuss')],
  format: 'book',
  publisher: Publisher('Bragelonne'),
  firstPublishedIn: Year(2007),
  synopsis: Synopsis(
    "Kvothe raconte sa propre légende : l'enfance sur les routes, la misère à Tarbean, " +
      "l'Université et la magie qu'on y apprend. Le récit d'un homme qui fut un héros et " +
      "tient aujourd'hui une auberge sous un faux nom.",
  ),
  genres: [Genre('Fantasy'), Genre('Roman initiatique')],
  pageCount: PageCount(662),
  isbn13: Isbn13('9782352943556'),
  coverUrl: CoverUrl('https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg?default=false'),
  series: {
    id: seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss'),
    name: SeriesName('Chronique du tueur de roi'),
    volume: VolumeNumber(1),
    kind: 'main',
  },
}
