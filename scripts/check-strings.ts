#!/usr/bin/env bun
/**
 * Keeps the iOS string catalogues whole: every string the app shows has its
 * French and its English.
 *
 * The strings are written in French in the Swift code, and the catalogues say
 * so (`sourceLanguage: fr`). English is the app's development language all the
 * same, so that a reader whose iPhone speaks neither gets English, as the
 * server answers them. The price of that: a string missing from the French
 * table falls back to the English one. So each string carries an explicit
 * French entry, copied from its key, which this script writes; a string with
 * no English is reported, and fails the run.
 *
 * Reads what the compiler extracted from the last build (`.stringsdata`, under
 * the derived data given), so a string added to the code and absent from the
 * catalogue is caught too.
 *
 *   bun scripts/check-strings.ts <derived-data>           # check, as CI does
 *   bun scripts/check-strings.ts <derived-data> --write   # sync the catalogues in place
 */
import { copyFile, mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { basename, dirname, join } from 'node:path'
import { $, Glob } from 'bun'

const ios = join(import.meta.dir, '../ios')

/** Each catalogue, and the build products its strings come from. */
const CATALOGUES = [
  { path: join(ios, 'Shiori/Localizable.xcstrings'), product: 'Shiori.build' },
  { path: join(ios, 'ShioriShare/Localizable.xcstrings'), product: 'ShioriShare.build' },
]

type Unit = { stringUnit?: { state: string; value: string }; variations?: unknown }
type Entry = {
  extractionState?: string
  shouldTranslate?: boolean
  localizations?: Record<string, Unit>
}
type Catalogue = { sourceLanguage: string; strings: Record<string, Entry>; version: string }

const [derivedData, ...flags] = process.argv.slice(2)
if (!derivedData) throw new Error('Usage: bun scripts/check-strings.ts <derived-data> [--write]')
const write = flags.includes('--write')

/** Xcode's own layout: two spaces, ` : ` between a key and its value. */
const serialize = (catalogue: Catalogue) =>
  `${JSON.stringify(catalogue, Object.keys(flatten(catalogue)).sort(), 2).replaceAll('": ', '" : ')}\n`

/** Every key at any depth, for `JSON.stringify` to write them sorted. */
function flatten(value: unknown, keys: Record<string, true> = {}): Record<string, true> {
  if (value && typeof value === 'object')
    for (const [key, inner] of Object.entries(value)) {
      keys[key] = true
      flatten(inner, keys)
    }
  return keys
}

const work = await mkdtemp(join(tmpdir(), 'shiori-strings-'))
const missing: string[] = []

for (const { path, product } of CATALOGUES) {
  // Under the configuration's folder: the project's own folder is named
  // Shiori.build too, and holds the extension's strings.
  const extracted = await Array.fromAsync(
    new Glob(`**/*-iphone*/${product}/**/*.stringsdata`).scan({ cwd: derivedData, absolute: true }),
  )
  if (extracted.length === 0)
    throw new Error(`No ${product} strings under ${derivedData}: build the app first`)

  // The sync runs on a copy: a check must not touch the working tree. The copy
  // keeps the catalogue's name, which is the table its strings are filed under.
  const synced = join(work, basename(product, '.build'), basename(path))
  await mkdir(dirname(synced), { recursive: true })
  await copyFile(path, synced)
  await $`xcrun xcstringstool sync ${synced} --stringsdata ${extracted}`.quiet()

  const catalogue: Catalogue = JSON.parse(await readFile(synced, 'utf8'))
  for (const [key, entry] of Object.entries(catalogue.strings)) {
    if (entry.extractionState === 'stale') {
      delete catalogue.strings[key]
      continue
    }
    entry.localizations ??= {}
    const localizations = entry.localizations
    localizations.fr ??= { stringUnit: { state: 'translated', value: key } }
    if (!localizations.en) missing.push(`${basename(product, '.build')}: ${JSON.stringify(key)}`)
  }

  const before = await readFile(path, 'utf8')
  const after = serialize(catalogue)
  if (before === after) continue
  if (write) {
    await writeFile(path, after)
    console.log(`${basename(product, '.build')}: catalogue synced`)
  } else missing.push(`${basename(product, '.build')}: catalogue out of date, run with --write`)
}

if (missing.length > 0) {
  console.error(`Strings without their English:\n${missing.map((line) => `  ${line}`).join('\n')}`)
  process.exit(1)
}
console.log('Every string has its French and its English.')
