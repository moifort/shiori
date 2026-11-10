import { getApps, initializeApp } from 'firebase-admin/app'
import {
  DocumentReference,
  Firestore,
  getFirestore,
  Query,
  Transaction,
} from 'firebase-admin/firestore'
import { meterFirestoreReads } from '~/system/read-meter'

// Over REST rather than gRPC: a cold instance's first read no longer loads the
// gRPC stack and its protos. Measured through the built bundle on a Mac, Node 22,
// 15 runs each against production: the first read 163 -> 121 ms (87 -> 56 ms of
// CPU), the reads after it unchanged, a burst of 30 at once no slower. Queries,
// `getAll`, `count()` and transactions are unary or server-streaming calls, all
// served over REST; only listeners need gRPC, and the server uses none.
// `settings` may be called once, before the first use: hence inside the guard.
if (getApps().length === 0) {
  initializeApp()
  getFirestore().settings({ preferRest: true })
}

export const db = () => getFirestore()

// The client exports `AggregateQuery` as a type only; its class is taken from
// an instance, which `count()` builds without any network call.
const AggregateQuery = Object.getPrototypeOf(db().collection('_').count()).constructor

meterFirestoreReads({ Firestore, Query, AggregateQuery, Transaction, DocumentReference })
