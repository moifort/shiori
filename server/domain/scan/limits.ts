/** Maximum decoded image size accepted (10 MB). Base64 adds ~33 % overhead, so
 *  the corresponding base64 string limit is ~14 MB of characters.
 *
 *  The app already downscales before sending, so this is not the real budget —
 *  it is the guard against a client that does not, which would otherwise bill a
 *  multi-megapixel photo's worth of image tokens to every scan. */
export const MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024
export const MAX_BASE64_LENGTH = Math.ceil((MAX_IMAGE_SIZE_BYTES * 4) / 3)

/** Returns true when the base64-encoded image fits within the decoded size limit. */
export const imageWithinSizeLimit = (base64Length: number): boolean =>
  base64Length <= MAX_BASE64_LENGTH
