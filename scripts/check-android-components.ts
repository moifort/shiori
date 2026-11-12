#!/usr/bin/env bun
/**
 * Keeps the Android components pure and previewed, as the iOS ones are
 * (scripts/check-ios-components.ts, docs/android-guide.md): everything under a
 * `components/` folder, and under `shared/components`, draws what it is given
 * and asks nothing of the server.
 *
 * A component fails the run when it
 * - calls the GraphQL client or a client's `live`;
 * - holds a ViewModel;
 * - listens to or posts change notices (`DataChanges`);
 * - reads the application context or the push registrar;
 * - declares a composable and no `@Preview`.
 *
 * Connected code — Screens, ViewModels, clients — lives beside the
 * `components/` folder and is not checked.
 *
 *   bun scripts/check-android-components.ts
 */
import { readFile } from 'node:fs/promises'
import { join, relative } from 'node:path'
import { Glob } from 'bun'

const root = join(import.meta.dir, '../android/app/src/main/java')

const RULES: { pattern: RegExp; says: string }[] = [
  { pattern: /\bGraphQLClient\.\w/, says: 'calls the API: hand it the value or an action instead' },
  { pattern: /\b[A-Z]\w*Client\.live\b/, says: 'reaches a live client: the Screen owns it' },
  { pattern: /\b[A-Z]\w*ViewModel\b/, says: 'holds a ViewModel: take its values and actions' },
  { pattern: /\bDataChanges\b/, says: 'listens to change notices: only Screens do' },
  {
    pattern: /\b(AppContext|PushRegistrar)\.\w/,
    says: 'reads a singleton: pass the value down, or provide it through a CompositionLocal',
  },
]

const files = [
  ...new Glob('**/features/*/components/**/*.kt').scanSync(root),
  ...new Glob('**/shared/components/**/*.kt').scanSync(root),
].sort()

const failures: string[] = []
for (const file of files) {
  const source = await readFile(join(root, file), 'utf8')
  // Comments say what the code once did; only the code is checked.
  const code = source
    .replace(/\/\*[\s\S]*?\*\//g, (comment) => comment.replace(/[^\n]/g, ''))
    .split('\n')
    .map((line) => line.replace(/\/\/.*$/, ''))
    .join('\n')
  code.split('\n').forEach((line, index) => {
    for (const rule of RULES) {
      if (rule.pattern.test(line)) failures.push(`${file}:${index + 1}: ${rule.says}`)
    }
  })
  // A composable the rest of the app can call: not private, named like a view
  // (a `Modifier.` extension is a style, not a view).
  const declaresComposable =
    /@Composable\s+(?:internal\s+)?fun\s+(?:<[^>]*>\s*)?[A-Z]\w*\s*\(/.test(code)
  if (declaresComposable && !code.includes('@Preview')) {
    failures.push(`${file}: declares a composable and no @Preview`)
  }
}

if (failures.length > 0) {
  console.error(`${failures.length} component rule(s) broken (docs/android-guide.md):`)
  for (const failure of failures) console.error(`  ${relative(process.cwd(), join(root, failure))}`)
  process.exit(1)
}
console.log(`${files.length} components, all pure and previewed.`)
