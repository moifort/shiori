import * as Sentry from '@sentry/node'

const traced =
  <TArgs extends unknown[], TReturn>(name: string, op: string, fn: (...args: TArgs) => TReturn) =>
  (...args: TArgs) =>
    Sentry.startSpan({ name, op }, () => fn(...args))

export const tracedModule = <T extends Record<string, (...args: never[]) => unknown>>(
  prefix: string,
  op: string,
  module: T,
): T =>
  Object.fromEntries(
    Object.entries(module).map(([key, fn]) => [key, traced(`${prefix}.${key}`, op, fn)]),
  ) as T
