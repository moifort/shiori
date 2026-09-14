import { ChangelogVersion } from '~/domain/changelog/primitives'
import type { ChangelogEntry } from '~/domain/changelog/types'

const headingPattern = /^##\s+(.+?)\s*$/
const bulletPattern = /^[-*]\s+(.+?)\s*$/
// Heading forms: "1.1 (2026.07.15)" (version + date), a bare "2026.07.15" (legacy),
// or a plain label such as "Unreleased" (no date).
const versionedPattern = /^(.+?)\s*\((\d{4})\.(\d{2})\.(\d{2})\)$/
const datedPattern = /^(\d{4})\.(\d{2})\.(\d{2})$/

const toUtcDate = (year: string, month: string, day: string): Date =>
  new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)))

const parseHeading = (line: string): { version: string; date: Date | null } | null => {
  const match = headingPattern.exec(line.trim())
  if (!match) return null
  const text = match[1].trim()
  const versioned = versionedPattern.exec(text)
  if (versioned)
    return {
      version: versioned[1].trim(),
      date: toUtcDate(versioned[2], versioned[3], versioned[4]),
    }
  const dated = datedPattern.exec(text)
  if (dated) return { version: text, date: toUtcDate(dated[1], dated[2], dated[3]) }
  return { version: text, date: null }
}

const isHeading = (line: string) => line.trimStart().startsWith('## ')

export const parseChangelog = (markdown: string): ChangelogEntry[] => {
  const entries: ChangelogEntry[] = []
  const lines = markdown.split(/\r?\n/)

  let current: ChangelogEntry | null = null

  for (const raw of lines) {
    const line = raw.trimEnd()
    if (isHeading(line)) {
      if (current) entries.push(current)
      const heading = parseHeading(line)
      if (!heading) {
        current = null
        continue
      }
      current = {
        version: ChangelogVersion(heading.version),
        date: heading.date,
        notes: [],
      }
      continue
    }
    if (!current) continue
    const bullet = bulletPattern.exec(line)
    if (bullet) current.notes.push(bullet[1])
  }

  if (current) entries.push(current)
  return entries
}
