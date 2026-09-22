import { describe, expect, test } from 'bun:test'
import { createLogger, type LogContext } from '~/system/logger'

const recorded = () => {
  const reports: { level: string; tag: string; message: string; context: LogContext }[] = []
  const logger = createLogger('scan', (level, tag, message, context) =>
    reports.push({ level, tag, message, context }),
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
