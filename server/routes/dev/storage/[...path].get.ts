import { readLocalObject } from '~/system/object-store'
import { ObjectPath } from '~/system/object-store/primitives'

// The development object store, read side. Shiori has no upload route: a cover
// arrives inside the scan mutation and the server writes it itself, so there is
// nothing for a client to PUT here. Compiled out of a production bundle.
export default defineEventHandler(async (event) => {
  if (!import.meta.dev) throw createError({ statusCode: 404, statusMessage: 'Not found' })

  const path = getRouterParam(event, 'path')
  if (!path) throw createError({ statusCode: 400, statusMessage: 'Missing object path' })

  try {
    const { body, contentType } = await readLocalObject(ObjectPath(path))
    setResponseHeader(event, 'content-type', contentType)
    return body
  } catch {
    throw createError({ statusCode: 404, statusMessage: 'Not found' })
  }
})
