import { migrations } from '~/system/migration/migrations'
import { runMigrations } from '~/system/migration/runner'

export default defineEventHandler(async (event) => {
  const result = await runMigrations(migrations)
  // A failed migration must fail the CI deploy step (curl -fsS gates on the status).
  if (result.outcome === 'failed') setResponseStatus(event, 500)
  return result
})
