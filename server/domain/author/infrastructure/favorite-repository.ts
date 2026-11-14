import type { AuthorFavorite } from '~/domain/author/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerReaderAndKey } from '~/utils/reader-documents'

// Flat, as every collection is, and keyed by the pair: one reader hearts one
// author once, so the pair is the identity. An author not hearted has no
// document at all, rather than one saying so.
//
// The Authors tab, the entry screen's rail and an author's page all want the
// reader's hearts: one query between them.
const favorites = oneDocumentPerReaderAndKey({
  collection: () =>
    db().collection('author-favorites').withConverter(genericDataConverter<AuthorFavorite>()),
  keyOf: (favorite) => favorite.authorKey,
  cacheTag: 'author-favorites',
  // Until migration 037 has run in production.
  legacyIdOf: (userId, key) => `${userId}--${key}`,
})

export const { findAllByUser, save, remove, removeAllByUser } = favorites
