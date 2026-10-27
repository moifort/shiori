import type * as AudibleApi from '~/domain/audible/infrastructure/audible-api'

/** Stands in for `~/domain/audible/infrastructure/audible-api` in every test file
 *  that mocks it.
 *
 *  `mock.module` leaks across files in one `bun test` run: whichever file registers
 *  the module first may be the one the domain binds to for the whole run. So every
 *  file registers this same object, whose functions dispatch to what the running
 *  file staged — the binding no longer depends on the order files are picked in. */
type Surface = keyof typeof AudibleApi
type Stand = (...args: never[]) => unknown
type Staged = Partial<Record<Surface, Stand>>

let staged: Staged = {}

/** Hands the module the answers of the file about to run. Call it in `beforeEach`:
 *  a function left out throws, rather than answering with another file's fake. */
export const stageAudibleApi = (stand: Staged) => {
  staged = stand
}

const dispatch =
  (name: Surface) =>
  (...args: unknown[]) => {
    const stand = staged[name] as ((...args: unknown[]) => unknown) | undefined
    if (!stand) throw new Error(`audible-api.${name} is not staged by this test file`)
    return stand(...args)
  }

export const fakeAudibleApi = {
  login: dispatch('login'),
  register: dispatch('register'),
  library: dispatch('library'),
  lastPositions: dispatch('lastPositions'),
  product: dispatch('product'),
  search: dispatch('search'),
  landingUrlOf: dispatch('landingUrlOf'),
} satisfies Record<Surface, unknown>
