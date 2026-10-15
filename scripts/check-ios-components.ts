#!/usr/bin/env bun
/**
 * Keeps the iOS components pure, as docs/ios-guide.md asks: everything under a
 * `components/` folder, and under `Shared/Components` and `Shared/Book`, draws
 * what it is given and asks nothing of the server.
 *
 * A component fails the run when it
 * - calls an API enum (`BookAPI.add`, `ScanAPI.lookUp`…) or a client's `.live`;
 * - reads a singleton (`PushRegistrar.shared`…), the system's own
 *   (`UIApplication.shared`, `UIPasteboard.general`) aside;
 * - listens to `NotificationCenter`;
 * - holds a ViewModel;
 * - declares a view and no `#Preview`.
 *
 * Connected code — Screens, ViewModels, clients — lives beside the
 * `components/` folder and is not checked.
 *
 *   bun scripts/check-ios-components.ts
 */
import { readFile } from 'node:fs/promises'
import { join, relative } from 'node:path'
import { Glob } from 'bun'

const root = join(import.meta.dir, '../ios/Shiori')

const RULES: { pattern: RegExp; says: string }[] = [
  {
    pattern: /\b[A-Z][A-Za-z]*API\.[a-z]/,
    says: 'calls an API: hand it the value or an action instead',
  },
  { pattern: /\b[A-Z][A-Za-z]*Client\.live\b/, says: 'reaches a live client: the Screen owns it' },
  {
    pattern: /\b(?!UIApplication\b|UIPasteboard\b)[A-Z][A-Za-z]*\.shared\b/,
    says: 'reads a singleton: pass the value down, or inject it through @Environment',
  },
  { pattern: /\bNotificationCenter\b/, says: 'listens to change notices: only Screens do' },
  {
    pattern: /\b[A-Z][A-Za-z]*ViewModel\b/,
    says: 'holds a ViewModel: take its values and actions',
  },
]

const files = [
  ...new Glob('Features/*/components/**/*.swift').scanSync(root),
  ...new Glob('Shared/Components/**/*.swift').scanSync(root),
  ...new Glob('Shared/Book/**/*.swift').scanSync(root),
].sort()

const failures: string[] = []
for (const file of files) {
  const source = await readFile(join(root, file), 'utf8')
  // Comments say what the code once did; only the code is checked.
  const code = source
    .split('\n')
    .map((line) => line.replace(/\/\/.*$/, ''))
    .join('\n')
  code.split('\n').forEach((line, index) => {
    for (const rule of RULES) {
      if (rule.pattern.test(line)) failures.push(`${file}:${index + 1}: ${rule.says}`)
    }
  })
  const declaresView = /\bstruct\s+\w+(<[^>]*>)?\s*:\s*[^{]*\bView\b/.test(code)
  if (declaresView && !code.includes('#Preview')) {
    failures.push(`${file}: declares a view and no #Preview`)
  }
}

if (failures.length > 0) {
  console.error(`${failures.length} component rule(s) broken (docs/ios-guide.md):`)
  for (const failure of failures) console.error(`  ${relative(process.cwd(), join(root, failure))}`)
  process.exit(1)
}
console.log(`${files.length} components, all pure and previewed.`)
