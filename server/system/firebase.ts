import { getApps, initializeApp } from 'firebase-admin/app'
import {
  DocumentReference,
  Firestore,
  getFirestore,
  Query,
  Transaction,
} from 'firebase-admin/firestore'
import { meterFirestoreReads } from '~/system/read-meter'

if (getApps().length === 0) initializeApp()

export const db = () => getFirestore()

// The client exports `AggregateQuery` as a type only; its class is taken from
// an instance, which `count()` builds without any network call.
const AggregateQuery = Object.getPrototypeOf(db().collection('_').count()).constructor

meterFirestoreReads({ Firestore, Query, AggregateQuery, Transaction, DocumentReference })
