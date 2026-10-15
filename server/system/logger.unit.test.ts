import { describe, expect, test } from 'bun:test'
import { createLogger, type LogContext, structuredLine } from '~/system/logger'

const recorded = () => {
  const reports: { level: string; tag: string; message: string; context: LogContext }[] = []
  const logger = createLogger(
    'scan',
    (level, tag, message, context) => reports.push({ level, tag, message, context }),
    () => {},
  )
  return { logger, reports }
}

describe('the logger', () => {
  // A problem the code recovers from is still one somebody has to hear about.
  test('reports every warning and error, with its error and context', () => {
    const { logger, reports } = recorded()
    const cause = new Error('Gemini returned no content')

    logger.warn('catalogue failed', { error: cause, series: 'Dune' })
    logger.error('scan failed')

    expect(reports).toEqual([
      {
        level: 'warning',
        tag: 'scan',
        message: 'catalogue failed',
        context: { error: cause, series: 'Dune' },
      },
      { level: 'error', tag: 'scan', message: 'scan failed', context: {} },
    ])
  })

  test('reports nothing for information', () => {
    const { logger, reports } = recorded()

    logger.info('usage recorded', { tokens: 12 })

    expect(reports).toEqual([])
  })
})

describe('a structured log line', () => {
  // Cloud Logging reads one JSON object per line: severity drives `severity>=WARNING`,
  // and every context key becomes a `jsonPayload` field.
  test('carries the severity, the tagged message and the context as fields', () => {
    const line = structuredLine('INFO', 'scan', 'gemini usage', { step: 'cover', searches: 4 })

    expect(line).not.toContain('\n')
    expect(JSON.parse(line)).toEqual({
      step: 'cover',
      searches: 4,
      severity: 'INFO',
      message: '[scan] gemini usage',
      tag: 'scan',
    })
  })

  test('keeps the error and its stack in the one entry', () => {
    const cause = new TypeError('fetch failed')

    const entry = JSON.parse(structuredLine('ERROR', 'scan', 'scan failed', { error: cause }))

    expect(entry.severity).toBe('ERROR')
    expect(entry.error).toEqual({ name: 'TypeError', message: 'fetch failed', stack: cause.stack })
  })

  test('writes an error that is not an Error as text', () => {
    const entry = JSON.parse(structuredLine('WARNING', 'scan', 'odd', { error: 404 }))

    expect(entry.error).toBe('404')
  })

  test('never lets the context overwrite the severity or the message', () => {
    const entry = JSON.parse(
      structuredLine('WARNING', 'scan', 'odd', { severity: 'DEBUG', message: 'other' }),
    )

    expect(entry).toMatchObject({ severity: 'WARNING', message: '[scan] odd' })
  })

  test('still logs the message when the context cannot be serialized', () => {
    const cycle: Record<string, unknown> = {}
    cycle.self = cycle

    expect(JSON.parse(structuredLine('INFO', 'scan', 'loop', { cycle }))).toEqual({
      severity: 'INFO',
      message: '[scan] loop',
      tag: 'scan',
    })
  })
})

describe('the logger writing', () => {
  test('writes every level with its severity', () => {
    const written: string[] = []
    const logger = createLogger(
      'scan',
      () => {},
      (severity, tag, message) => written.push(`${severity} ${tag} ${message}`),
    )

    logger.info('a')
    logger.warn('b')
    logger.error('c')

    expect(written).toEqual(['INFO scan a', 'WARNING scan b', 'ERROR scan c'])
  })
})
