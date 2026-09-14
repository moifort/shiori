import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const root = resolve(import.meta.dir, '..')
const target = resolve(root, 'server/system/changelog-content.ts')

// CHANGELOG.md is the English source; every other language is served to the app
// in its own file, picked at request time from `Accept-Language`. Keep this list
// in sync with SUPPORTED_LANGUAGES in server/domain/shared/language.ts.
const files: Record<string, string> = {
  en: 'CHANGELOG.md',
  fr: 'CHANGELOG.fr.md',
}

const byLanguage: Record<string, string> = {}
for (const [language, file] of Object.entries(files)) {
  const path = resolve(root, file)
  if (!existsSync(path)) continue
  byLanguage[language] = readFileSync(path, 'utf8')
}

const banner =
  '// Generated from the CHANGELOG.*.md files by scripts/generate-changelog-asset.ts. Do not edit.\n'
const body = `export const changelogMarkdownByLanguage: Record<string, string> = ${JSON.stringify(byLanguage, null, 2)}\n`

mkdirSync(dirname(target), { recursive: true })
writeFileSync(target, banner + body)
