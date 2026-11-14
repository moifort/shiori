import { AudibleQuery } from '~/domain/audible/query'
import { storeUrlOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedStateEnum } from '~/domain/awaited-edition/infrastructure/graphql/types'
import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { releaseViewOf } from '~/domain/release/business-rules'
import { ReleaseQuery } from '~/domain/release/query'
import type { ReleaseShown, ReleaseView } from '~/domain/release/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { objectStore } from '~/system/object-store'

const ReleaseSeriesType = builder
  .objectRef<NonNullable<ReleaseView['series']>>('ReleaseSeries')
  .implement({
    description: 'The saga a release is a volume of.',
    fields: (t) => ({
      seriesId: t.field({
        type: 'SeriesId',
        nullable: true,
        description: 'Its saga, in the edition shown. Null when only its name is known.',
        resolve: (series) => series.seriesId ?? null,
      }),
      name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
      volume: t.field({
        type: 'VolumeNumber',
        nullable: true,
        resolve: (series) => series.volume ?? null,
      }),
    }),
  })

export const ReleaseType = builder.objectRef<ReleaseView>('Release').implement({
  description:
    'A book the reader does not hold — an edition awaited, an award winner, a discovery, a ' +
    'saga’s volume — as every list and its page show it: one record, shared by every ' +
    'reader, made of what the web found of the edition and what its page described. ' +
    'Nothing is to be merged on the device: a tile and the page it opens draw this.',
  fields: (t) => ({
    key: t.string({
      description: 'The release, whoever shows it: the same book, format and edition.',
      resolve: (view) => view.key,
    }),
    title: t.field({
      type: 'BookTitle',
      description: 'Its title as shown: the edition’s once found, else the original’s.',
      resolve: (view) => view.title,
    }),
    originalTitle: t.field({ type: 'BookTitle', resolve: (view) => view.originalTitle }),
    authors: t.field({ type: ['AuthorName'], resolve: (view) => view.authors }),
    format: t.field({
      type: BookFormatEnum,
      description: 'What the book is: a novel, a manga, a recording.',
      resolve: (view) => view.format,
    }),
    releaseFormat: t.field({ type: ReleaseFormatEnum, resolve: (view) => view.releaseFormat }),
    language: t.field({
      type: BookLanguageEnum,
      description: 'The language of the edition.',
      resolve: (view) => view.language,
    }),
    originalLanguage: t.field({ type: BookLanguageEnum, resolve: (view) => view.originalLanguage }),
    state: t.field({ type: AwaitedStateEnum, resolve: (view) => view.state }),
    watched: t.boolean({
      description: 'Whether the web was ever searched for it.',
      resolve: (view) => view.watched,
    }),
    date: t.string({
      nullable: true,
      description:
        'When it comes out or came out, as precisely as announced: `YYYY`, `YYYY-MM` or ' +
        '`YYYY-MM-DD`. Null until found, and for an edition announced with no date.',
      resolve: (view) => view.date ?? null,
    }),
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (view) => view.isbn13 ?? null }),
    coverUrl: t.string({
      nullable: true,
      description:
        'The edition’s own cover once found, else the cover of the book shown, else the ' +
        'one its page’s description found.',
      resolve: async (view) =>
        view.coverUrl ??
        (view.coverPath ? await objectStore().downloadUrl(view.coverPath) : null) ??
        view.describedCoverUrl ??
        view.fallbackCoverUrl ??
        null,
    }),
    storeUrl: t.string({
      nullable: true,
      description:
        'Where to get it: the recording’s page on the reader’s Audible store, which the ' +
        'Audible app opens on the title, or a search for it on the store of its language ' +
        'while Audible has not confirmed it; the printed edition’s page on Amazon once its ' +
        'ISBN is known, a search for its title and author until then. Null until the edition ' +
        'is found.',
      resolve: async (view, _args, { userId }) => {
        const asin = view.releaseFormat === 'audiobook' ? view.asin : undefined
        const own = asin ? await AudibleQuery.recordingUrlOf(userId, asin) : undefined
        if (own) return own
        if (!view.found) return null
        return storeUrlOf(view.releaseFormat, view.language, view.found, view.authors[0]) ?? null
      },
    }),
    series: t.field({
      type: ReleaseSeriesType,
      nullable: true,
      resolve: (view) => view.series ?? null,
    }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (view) => view.publisher ?? null,
    }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      resolve: (view) => view.firstPublishedIn ?? null,
    }),
    synopsis: t.field({
      type: 'Synopsis',
      nullable: true,
      resolve: (view) => view.synopsis ?? null,
    }),
    genre: t.field({ type: GenreEnum, nullable: true, resolve: (view) => view.genre ?? null }),
    subgenres: t.field({ type: ['Subgenre'], resolve: (view) => view.subgenres }),
    pageCount: t.field({
      type: 'PageCount',
      nullable: true,
      description: 'Null for a recording.',
      resolve: (view) => view.pageCount ?? null,
    }),
    narrators: t.field({
      type: ['NarratorName'],
      description: 'Who reads the recording, as Audible lists them. Empty for a printed book.',
      resolve: (view) => view.narrators,
    }),
    durationMinutes: t.int({
      nullable: true,
      description: 'The recording’s running time, as Audible gives it.',
      resolve: (view) => view.durationMinutes ?? null,
    }),
    described: t.boolean({
      description:
        'Whether its page’s description is kept and fresh. False, opening its page asks ' +
        '`describeRelease` for it, which answers this release completed.',
      resolve: (view) => view.described,
    }),
  }),
})

/** A release as the reader is shown it, its document read for the request —
 *  once, whoever asks it — so a list cached for the reader draws the
 *  description its page kept since. */
export const releaseViewFor = async (
  shown: ReleaseShown,
  event: Parameters<typeof languageOf>[0],
): Promise<ReleaseView> => {
  const release = (await ReleaseQuery.byKeys([shown.key])).get(shown.key)
  return releaseViewOf(shown, release, languageOf(event), new Date())
}
