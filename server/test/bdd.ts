// Static import only — `await import()` of this module hangs: the `then`
// export makes the module namespace a thenable that never resolves.
import { describe, test } from 'bun:test'

export const feature = describe
export const scenario = test

export const given = (description: string) => console.log(`  Given ${description}`)
export const when = (description: string) => console.log(`  When ${description}`)
// biome-ignore lint/suspicious/noThenProperty: BDD DSL function, not a thenable
export const then = (description: string) => console.log(`  Then ${description}`)
export const and = (description: string) => console.log(`  And ${description}`)
