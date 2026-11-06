/**
 * Turns the iOS string catalogue into the table the Android app reads.
 *
 * The iOS catalogue is the single source of the app's copy: its keys are the French text
 * written in the Swift code, with an English translation beside each. Android looks strings
 * up by the very same French key (`L("À lire")`), so a screen ported from Swift keeps its
 * strings verbatim and a translation added for iOS reaches Android at the next run.
 *
 * Usage: `bun scripts/android-strings.ts` (writes android/app/src/main/assets/strings.json),
 * `bun scripts/android-strings.ts --check` (fails when the file is stale).
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

type StringUnit = { stringUnit?: { value: string }; variations?: Variations }
type Variations = { plural?: Record<string, { stringUnit: { value: string } }> }
type Catalogue = {
  strings: Record<string, { localizations?: Record<string, StringUnit> }>
}

/** One language's rendering of a key: a plain string, or plural forms keyed by category. */
type Rendering = string | Record<string, string>

const root = join(import.meta.dir, '..')
const source = join(root, 'ios/Shiori/Localizable.xcstrings')
const target = join(root, 'android/app/src/main/assets/strings.json')

const renderingOf = (unit: StringUnit | undefined): Rendering | undefined => {
  if (!unit) return undefined
  if (unit.variations?.plural) {
    return Object.fromEntries(
      Object.entries(unit.variations.plural).map(([category, form]) => [
        category,
        form.stringUnit.value,
      ]),
    )
  }
  return unit.stringUnit?.value
}

const catalogue = JSON.parse(readFileSync(source, 'utf8')) as Catalogue
const table: Record<string, { fr?: Rendering; en?: Rendering }> = {}
for (const key of Object.keys(catalogue.strings).sort()) {
  const localizations = catalogue.strings[key]?.localizations ?? {}
  const fr = renderingOf(localizations.fr)
  const en = renderingOf(localizations.en)
  if (fr === undefined && en === undefined) continue
  table[key] = {
    ...(fr !== undefined && fr !== key ? { fr } : {}),
    ...(en !== undefined ? { en } : {}),
  }
}

const output = `${JSON.stringify(table, null, 1)}\n`
if (process.argv.includes('--check')) {
  const current = (() => {
    try {
      return readFileSync(target, 'utf8')
    } catch {
      return ''
    }
  })()
  if (current !== output) {
    process.stderr.write('android strings.json is stale: run bun scripts/android-strings.ts\n')
    process.exit(1)
  }
} else {
  writeFileSync(target, output)
  process.stdout.write(`${Object.keys(table).length} strings → ${target}\n`)
}
