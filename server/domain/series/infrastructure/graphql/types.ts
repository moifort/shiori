import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import type { BookLanguage } from '~/domain/book/types'
import { splitBySpine } from '~/domain/series/business-rules'
import { VolumeKindEnum } from '~/domain/series/infrastructure/graphql/enums'
import type { Series, Volume } from '~/domain/series/types'
import { builder } from '~/domain/shared/graphql/builder'

type VolumeRelease = { language: BookLanguage; volume: Volume }

const VolumeReleaseType = builder.objectRef<VolumeRelease>('VolumeRelease').implement({
  description: 'A volume in one language, as the weekly release watch found it: out, or announced.',
  fields: (t) => ({
    language: t.field({ type: BookLanguageEnum, resolve: ({ language }) => language }),
    date: t.string({
      description:
        'When it came out or comes out in that language, as precisely as announced: ' +
        '`YYYY`, `YYYY-MM` or `YYYY-MM-DD`.',
      resolve: ({ language, volume }) => volume.releases?.[language] ?? '',
    }),
    title: t.field({
      type: 'BookTitle',
      description: 'Its title in that language.',
      resolve: ({ language, volume }) => volume.titles?.[language] ?? volume.title,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'The publisher’s cover of that edition, found by its ISBN.',
      resolve: ({ language, volume }) => volume.covers?.[language] ?? null,
    }),
  }),
})

export const VolumeType = builder.objectRef<Volume>('Volume').implement({
  description:
    'One entry of a saga catalogue, owned or not.\n\n' +
    'The catalogue lists what exists in the world, so most volumes here are books ' +
    'the reader does not own: those are proposals, and nothing enters a library ' +
    'until the reader adds it.',
  fields: (t) => ({
    number: t.field({
      type: 'VolumeNumber',
      nullable: true,
      description: 'Position along the spine. Null for anything that is not a main volume.',
      resolve: (volume) => volume.number ?? null,
    }),
    title: t.field({ type: 'BookTitle', resolve: (volume) => volume.title }),
    publishedIn: t.field({
      type: 'Year',
      nullable: true,
      description:
        'Publication year. A year in the future marks a volume that has been ' +
        'announced but has not shipped.',
      resolve: (volume) => volume.publishedIn ?? null,
    }),
    kind: t.field({ type: VolumeKindEnum, resolve: (volume) => volume.kind }),
    releases: t.field({
      type: [VolumeReleaseType],
      description:
        'When the volume came out or comes out in each language the release watch ' +
        'found it in. What decides, for the reader holding one edition, whether the ' +
        'volume is out: a volume out in English can be months away in French. A ' +
        'volume announced to the day counts in the saga at once — a reader up to date ' +
        'is then waiting for it, not done.',
      resolve: (volume) =>
        Object.keys(volume.releases ?? {}).map((language) => ({
          language: language as BookLanguage,
          volume,
        })),
    }),
  }),
})

export const SeriesType = builder.objectRef<Series>('Series').implement({
  description:
    'The shared catalogue of a saga.\n\n' +
    'A public fact with no reference to any reader: one document serves everyone, ' +
    'which is what lets a single AI call pay for the whole saga. It is never ' +
    'exposed through library sharing, which shows books only.\n\n' +
    'Volumes are stored in publication order, which is verifiable. Reading order ' +
    'differs on many sagas and is an opinion.\n\n' +
    "A `provisional` catalogue is the exception: the reader's own count of the " +
    'volumes, drawn on the fly for a saga nobody has described, and never stored.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', resolve: (series) => series.id }),
    name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
    author: t.field({ type: 'AuthorName', resolve: (series) => series.author }),
    description: t.field({
      type: 'SeriesDescription',
      nullable: true,
      resolve: (series) => series.description ?? null,
    }),
    volumes: t.field({
      type: [VolumeType],
      description: 'Every volume, in catalogue order: the numbered spine, then related works.',
      resolve: (series) => {
        const { spine, relatedWorks } = splitBySpine(series)
        return [...spine, ...relatedWorks]
      },
    }),
    spine: t.field({
      type: [VolumeType],
      description: 'The numbered main volumes only, ascending.',
      resolve: (series) => splitBySpine(series).spine,
    }),
    relatedWorks: t.field({
      type: [VolumeType],
      description: 'Prequels, spin-offs, novellas and companions — everything off the spine.',
      resolve: (series) => splitBySpine(series).relatedWorks,
    }),
    catalogedAt: t.field({ type: 'DateTime', resolve: (series) => series.catalogedAt }),
    provisional: t.boolean({
      description:
        "Drawn from the reader's own count of the volumes rather than from the " +
        'world: nobody has catalogued the saga, and they said how many volumes it ' +
        "has with `declareSeriesVolumeCount`. The reader's volumes sit at their " +
        "numbers and the saga's name stands in for the rest, with no year and no " +
        'description. `refreshSeries` asks the world for the real one.',
      resolve: (series) => series.provisional === true,
    }),
  }),
})
