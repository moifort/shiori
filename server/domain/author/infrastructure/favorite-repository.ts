import type { AuthorFavorite } from '~/domain/author/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUserAndKey } from '~/utils/user-documents'

// Flat, as every collection is, and keyed by the pair: one reader hearts one
// author once, so the pair is the identity. An author not hearted has no
// document at all, rather than one saying so.
//
// The Authors tab, the entry screen's rail and an author's page all want the
// reader's hearts: one query between them.
const favorites = oneDocumentPerUserAndKey({
  collection: () =>
    db().collection('author-favorites').withConverter(genericDataConverter<AuthorFavorite>()),
  keyOf: (favorite) => favorite.authorKey,
  cacheTag: 'author-favorites',
})

export const { findAllByUser, save, remove, removeAllByUser } = favorites
