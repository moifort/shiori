import type { UserId } from '~/domain/shared/types'
import { ObjectPath } from '~/system/object-store/primitives'
import type { ObjectPath as ObjectPathValue } from '~/system/object-store/types'

/** Where a reader's avatar photos live in the bucket, derived from the owner
 *  and never chosen by the caller. */
export const avatarPrefixOf = (userId: UserId): ObjectPathValue => ObjectPath(`avatars/${userId}/`)

/** One file per photo, named by when it arrived: a new photo is a new path, so
 *  the phone never draws the previous face from a URL it cached. */
export const avatarPathOf = (userId: UserId, at: Date): ObjectPathValue =>
  ObjectPath(`${avatarPrefixOf(userId)}${at.getTime()}.jpg`)

/** A JPEG starts with FF D8 FF: anything else is not a photo the app took. */
export const isJpeg = (bytes: Buffer): boolean =>
  bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff

/** 2 MB decoded. The app sends a 512-point square, a few dozen kilobytes. */
export const MAX_AVATAR_BYTES = 2 * 1024 * 1024
