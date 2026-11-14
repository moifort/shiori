import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** The app's languages a description could be written in, when this ran. */
const APP_LANGUAGES = ['fr', 'en'] as const

type Doc = Record<string, unknown>
type Kept = { description?: Doc; describedAt?: unknown }

const text = (value: unknown) => (typeof value === 'string' ? value : undefined)

/** The key a description was kept under before this migration, as a page
 *  asked for it: the shown title and first author, the format, the edition's
 *  language when it named one, the volume, the language it was written in. */
const oldDescriptionKeyOf = (
  title: string,
  author: string | undefined,
  format: string,
  language: string | undefined,
  volume: number | undefined,
  appLanguage: string,
) =>
  [slugify(title), slugify(author ?? ''), format, language ?? '-', volume ?? '-', appLanguage].join(
    '~',
  )

/** `releaseKeyOf` as it stood when this ran. */
const releaseKeyOf = (
  title: string,
  author: string | undefined,
  format: string,
  language: string,
) => `${slugify(title)}--${slugify(author ?? '')}--${format}--${language}`

/** One release, and the old keys its descriptions may sit under, by the
 *  language they are written in, with the shown book each one describes. */
type Plan = {
  key: string
  base: Doc
  candidates: { appLanguage: string; oldKey: string; describedFrom: string }[]
}

const candidatesOf = (
  title: string,
  author: string | undefined,
  format: string,
  language: string | undefined,
  volume: number | undefined,
) =>
  APP_LANGUAGES.map((appLanguage) => ({
    appLanguage,
    oldKey: oldDescriptionKeyOf(title, author, format, language, volume, appLanguage),
    describedFrom: `${slugify(title)}~${language ?? '-'}`,
  }))

/** An edition watch, and its page's description: of the original while
 *  nobody announced it, of the edition once found. */
const watchPlanOf = (watch: Doc): Plan | undefined => {
  const key = text(watch.key)
  const title = text(watch.title)
  const format = text(watch.format)
  if (!key || !title || !format) return undefined
  const found = watch.found as Doc | undefined
  const author = text(watch.author)
  const foundTitle = text(found?.title)
  return {
    key,
    base: watch,
    candidates: foundTitle
      ? candidatesOf(foundTitle, author, format, undefined, undefined)
      : candidatesOf(title, author, format, text(watch.originalLanguage), undefined),
  }
}

/** A saga's volume a page described: a release of its own, named by the saga. */
const volumePlansOf = (watch: Doc): Plan[] => {
  const seriesId = text(watch.seriesId)
  const language = text(watch.language)
  const name = text(watch.name)
  if (!seriesId || !language || !name) return []
  const author = text(watch.author)
  const format = seriesId.endsWith('--audio') ? 'audiobook' : 'book'
  const volumes = Array.isArray(watch.volumes) ? (watch.volumes as Doc[]) : []
  return volumes.flatMap((volume) => {
    const title = text(volume.title)
    const number = typeof volume.number === 'number' ? volume.number : undefined
    if (!title || number === undefined) return []
    return [
      {
        key: releaseKeyOf(title, author, format, language),
        base: {
          key: releaseKeyOf(title, author, format, language),
          title,
          ...(author ? { author } : {}),
          originalLanguage: language,
          series: { name, volume: number },
          format,
          language,
        },
        candidates: candidatesOf(title, author, format, language, number),
      },
    ]
  })
}

/** Every edition watch and every page's description into one shared release.
 *
 *  An edition's watch lived in `edition-watches` and its page's description
 *  in `release-descriptions`, under a key each phone worked out on its own,
 *  so a list and the page it opened could show two different books. Both now
 *  live in `releases/{key}`, which every list and every page read. The
 *  descriptions of an edition watched and of a saga's volume move with it;
 *  the others — a winner or a discovery never looked for — are asked again
 *  the next time their page opens. The old collections go, and so do the
 *  state of the hourly edition pass and the Découvrir projections, which were
 *  built from them. */
export const releasesHoldTheirDescriptions: Migration = {
  version: MigrationVersion(36),
  name: MigrationName('releases-hold-their-descriptions'),
  migrate: async ({ db }) => {
    const [watches, sagas, descriptions] = await Promise.all([
      db.collection('edition-watches').get(),
      db.collection('saga-watches').get(),
      db.collection('release-descriptions').get(),
    ])
    const kept = new Map(descriptions.docs.map((doc) => [doc.ref.id, doc.data() as Kept]))
    const plans = [
      ...watches.docs.flatMap((doc) => watchPlanOf(doc.data()) ?? []),
      ...sagas.docs.flatMap((doc) => volumePlansOf(doc.data())),
    ]
    const releases = new Map<string, Doc>()
    for (const plan of plans) {
      const found = Object.fromEntries(
        plan.candidates.flatMap(({ appLanguage, oldKey, describedFrom }) => {
          const one = kept.get(oldKey)
          return one?.description
            ? [
                [
                  appLanguage,
                  { description: one.description, describedAt: one.describedAt, describedFrom },
                ],
              ]
            : []
        }),
      )
      const isWatch = plan.base.checkedAt !== undefined
      if (!isWatch && Object.keys(found).length === 0) continue
      const previous = releases.get(plan.key)
      releases.set(plan.key, {
        ...plan.base,
        ...previous,
        descriptions: { ...(previous?.descriptions as Doc | undefined), ...found },
      })
    }
    for (const part of chunk([...releases.entries()], BATCH_SIZE)) {
      const batch = db.batch()
      for (const [key, release] of part) {
        const { descriptions: held, ...rest } = release
        const written =
          held && Object.keys(held as Doc).length > 0 ? { ...rest, descriptions: held } : rest
        batch.set(db.collection('releases').doc(key), written)
      }
      await batch.commit()
    }
    const projections = await db.collection('discovery-projections').get()
    const gone = [
      ...watches.docs.map((doc) => doc.ref),
      ...descriptions.docs.map((doc) => doc.ref),
      ...projections.docs.map((doc) => doc.ref),
      db.collection('edition-pass').doc('hourly'),
    ]
    for (const part of chunk(gone, BATCH_SIZE)) {
      const batch = db.batch()
      for (const ref of part) batch.delete(ref)
      await batch.commit()
    }
    return { ok: true, transformed: releases.size }
  },
}
