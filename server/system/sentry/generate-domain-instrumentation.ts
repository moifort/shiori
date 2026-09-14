import { existsSync, readdirSync, readFileSync } from 'node:fs'

export const generateDomainInstrumentation = () => {
  const domains = readdirSync('server/domain', { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)

  const candidates = ['command.ts', 'query.ts', 'use-case.ts', 'index.ts']
  const files = domains.flatMap((domain) =>
    candidates.map((file) => `server/domain/${domain}/${file}`).filter((path) => existsSync(path)),
  )

  const modules = files
    .map((file) => {
      const content = readFileSync(file, 'utf-8')
      const namespaceMatch = content.match(/export namespace (\w+)/)
      if (!namespaceMatch) return null
      const name = namespaceMatch[1]
      const op = file.includes('command')
        ? 'domain.command'
        : file.includes('query')
          ? 'domain.query'
          : file.includes('use-case')
            ? 'domain.use-case'
            : 'domain'
      const importPath = `~/${file.replace('server/', '').replace('.ts', '')}`
      return { name, op, importPath }
    })
    .filter((module) => module !== null)

  const imports = modules
    .map(({ name, importPath }) => `import { ${name} } from '${importPath}'`)
    .join('\n')
  const wraps = modules
    .map(({ name, op }) => `  Object.assign(${name}, tracedModule('${name}', '${op}', ${name}))`)
    .join('\n')

  return `
import { tracedModule } from '~/system/sentry/tracing'
${imports}

export const instrumentDomains = () => {
${wraps}
}
`
}
