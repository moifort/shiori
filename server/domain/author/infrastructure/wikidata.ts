import { authorKeyOf, PortraitUrl } from '~/domain/author/primitives'
import type { PortraitUrl as PortraitUrlType } from '~/domain/author/types'
import type { AuthorName } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { isTimeout } from '~/utils/fetch'

const logger = createLogger('wikidata')

/** A slow answer costs the reader a longer opening for a cosmetic field. The
 *  whole lookup, search to thumbnail, has this long. */
const LOOKUP_TIMEOUT_MS = 4000

/** What an author may be on Wikidata: a person, or the pen name several share —
 *  Carmen Mola is three writers. */
const PEOPLE = new Set([
  'Q5', // human
  'Q61002', // pseudonym
  'Q16017119', // collective pseudonym
])

/** 330 px wide, as Wikipedia's own thumbnails: an 84-point circle on a Retina screen. */
const THUMB_WIDTH = 330

/** How many of the author's Wikipedias are asked for a lead photograph when
 *  Wikidata records none. */
const WIKIS_ASKED = 10

// Wikimedia asks every client to say who it is, and throttles those that don't.
const headers = { 'user-agent': 'Shiori/1.0 (https://github.com/moifort/shiori)' }

/** The occupations that make a namesake the author rather than someone else:
 *  the ones the writers of a reading library carry on Wikidata, from novelist
 *  and mangaka to the historian or journalist of an essay. */
const WRITING_OCCUPATIONS = new Set([
  'Q36180', // writer
  'Q482980', // author
  'Q6625963', // novelist
  'Q28389', // screenwriter
  'Q18844224', // science fiction writer
  'Q10297252', // crime fiction writer
  'Q4853732', // children's writer
  'Q12144794', // prose writer
  'Q15949613', // short story writer
  'Q15980158', // non-fiction writer
  'Q11774202', // essayist
  'Q49757', // poet
  'Q214917', // playwright
  'Q18814623', // autobiographer
  'Q4263842', // literary critic
  'Q333634', // translator
  'Q1930187', // journalist
  'Q201788', // historian
  'Q4964182', // philosopher
  'Q11892507', // comics writer
  'Q715301', // comics artist
  'Q109517242', // comics creator
  'Q191633', // mangaka
  'Q1114448', // cartoonist
  'Q644687', // illustrator
])

type Claim = { mainsnak?: { datavalue?: { value?: unknown } } }
type Entity = {
  id: string
  labels?: Record<string, { value: string }>
  aliases?: Record<string, { value: string }[]>
  claims?: Record<string, Claim[]>
  sitelinks?: Record<string, { title: string }>
}
type Page = { thumbnail?: { source?: string } }

const ask = async <T>(url: string, signal: AbortSignal): Promise<T> => {
  const response = await fetch(url, { headers, signal })
  if (!response.ok) throw new Error(`${new URL(url).host} answered ${response.status}`)
  return (await response.json()) as T
}

const idsOf = (entity: Entity, property: string) =>
  (entity.claims?.[property] ?? []).map((claim) => claim.mainsnak?.datavalue?.value)

const entityIdsOf = (entity: Entity, property: string) =>
  idsOf(entity, property).map((value) => (value as { id?: string } | undefined)?.id)

/** Whether this entity is the author: a person or a pen name, writing, under
 *  the very name the library shows — "Jasmine Mas" is not "Jasmine Masters". */
const isTheAuthor = (entity: Entity, name: AuthorName) => {
  const key = authorKeyOf(name)
  const names = [
    ...Object.values(entity.labels ?? {}).map((label) => label.value),
    ...Object.values(entity.aliases ?? {}).flatMap((aliases) => aliases.map((a) => a.value)),
  ]
  return (
    entityIdsOf(entity, 'P31').some((id) => id !== undefined && PEOPLE.has(id)) &&
    entityIdsOf(entity, 'P106').some((id) => id !== undefined && WRITING_OCCUPATIONS.has(id)) &&
    names.some((label) => authorKeyOf(label) === key)
  )
}

/** The Wikipedias that have a page on the author, the English and French
 *  ones first: Wikidata lists the others alphabetically. */
const wikipediasOf = (entity: Entity) =>
  Object.entries(entity.sitelinks ?? {})
    .flatMap(([site, { title }]) => {
      const wiki = /^([a-z]{2,3})wiki$/.exec(site)?.[1]
      return wiki ? [{ wiki, title }] : []
    })
    .toSorted((a, b) => rankOf(a.wiki) - rankOf(b.wiki))

const rankOf = (wiki: string) => ({ en: 0, fr: 1 })[wiki] ?? 2

/** Commons' thumbnail of a file, by name. */
const commonsThumbOf = async (file: string, signal: AbortSignal) => {
  const query = new URLSearchParams({
    action: 'query',
    format: 'json',
    prop: 'pageimages',
    piprop: 'thumbnail',
    pithumbsize: String(THUMB_WIDTH),
    titles: `File:${file}`,
  })
  const answer = await ask<{ query?: { pages?: Record<string, Page> } }>(
    `https://commons.wikimedia.org/w/api.php?${query}`,
    signal,
  )
  return Object.values(answer.query?.pages ?? {})[0]?.thumbnail?.source
}

/** The free photograph at the top of one Wikipedia's page on the author, or
 *  undefined. Non-free images are refused: only a free file may be shown
 *  outside the encyclopedia. */
const leadPhotoOf = async (
  { wiki, title }: { wiki: string; title: string },
  signal: AbortSignal,
) => {
  const query = new URLSearchParams({
    action: 'query',
    format: 'json',
    prop: 'pageimages',
    piprop: 'thumbnail',
    pithumbsize: String(THUMB_WIDTH),
    pilicense: 'free',
    titles: title,
  })
  try {
    const answer = await ask<{ query?: { pages?: Record<string, Page> } }>(
      `https://${wiki}.wikipedia.org/w/api.php?${query}`,
      signal,
    )
    return Object.values(answer.query?.pages ?? {})[0]?.thumbnail?.source
  } catch {
    // One Wikipedia out of ten failing leaves the others to answer.
    return undefined
  }
}

/** Wikidata's photograph of an author, or undefined when it has none.
 *
 *  Wikipedia is read by page title, and a name lands on a namesake's page, a
 *  disambiguation, or an English page with no photo while the Czech or Hebrew
 *  one has a free portrait. Wikidata knows the person behind every page: its
 *  search returns the entities the name may be, and only a human whose
 *  occupation is writing, under that very name, is kept — the one with the
 *  most Wikipedias when several are. Their image (P18) is the portrait; with
 *  none recorded, the lead photograph of any of their Wikipedia pages is.
 *
 *  Never throws: a missing portrait is the initials, not a failed page. */
export const wikidataPortraitOf = async (
  name: AuthorName,
): Promise<PortraitUrlType | undefined> => {
  const signal = AbortSignal.timeout(LOOKUP_TIMEOUT_MS)
  try {
    const search = new URLSearchParams({
      action: 'wbsearchentities',
      format: 'json',
      language: 'en',
      type: 'item',
      limit: '7',
      search: name,
    })
    const found = await ask<{ search?: { id: string }[] }>(
      `https://www.wikidata.org/w/api.php?${search}`,
      signal,
    )
    const ids = (found.search ?? []).map(({ id }) => id)
    if (ids.length === 0) return undefined

    const read = new URLSearchParams({
      action: 'wbgetentities',
      format: 'json',
      props: 'labels|aliases|claims|sitelinks',
      ids: ids.join('|'),
    })
    const { entities } = await ask<{ entities?: Record<string, Entity> }>(
      `https://www.wikidata.org/w/api.php?${read}`,
      signal,
    )
    const author = Object.values(entities ?? {})
      .filter((entity) => isTheAuthor(entity, name))
      .toSorted((a, b) => wikipediasOf(b).length - wikipediasOf(a).length)[0]
    if (!author) return undefined

    const image = idsOf(author, 'P18').find((value) => typeof value === 'string') as
      | string
      | undefined
    const source = image
      ? await commonsThumbOf(image, signal)
      : (
          await Promise.all(
            wikipediasOf(author)
              .slice(0, WIKIS_ASKED)
              .map((page) => leadPhotoOf(page, signal)),
          )
        ).find((photo) => photo !== undefined)
    return source ? PortraitUrl(source) : undefined
  } catch (error) {
    // Running out of time is the cutoff above doing its job, not a failure to look into.
    if (isTimeout(error)) logger.info('Wikidata portrait lookup timed out', { name })
    else logger.warn('Wikidata portrait lookup failed', { error, name })
    return undefined
  }
}
