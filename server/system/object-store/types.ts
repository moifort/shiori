import type { Brand } from 'ts-brand'

/** Where the bytes live in the bucket. Derived from the owner and the book,
 *  never chosen by the caller: a caller-supplied path is a path traversal. */
export type ObjectPath = Brand<string, 'ObjectPath'>
/** A time-limited URL to read one object, signed by the server. */
export type SignedUrl = Brand<string, 'SignedUrl'>
export type ContentType = Brand<string, 'ContentType'>
export type ByteSize = Brand<number, 'ByteSize'>

/** What the bucket knows about an object, read back to check what really landed. */
export type StoredObject = { contentType: ContentType; size: ByteSize }
