# Data recovery — Firestore protections and runbook

What protects production data, and what to do when it is lost. Read this before touching
anything: a hurried restore over live writes does more damage than the incident.

## What is in place

Both settings live on `google_firestore_database.default` in `infra/firebase.tf`, applied by
the Deploy workflow (since 2026-10-19, commit 5dc4f24).

| Protection | Covers | Retention |
|---|---|---|
| Delete protection (`DELETE_PROTECTION_ENABLED`) | Deleting the `(default)` database from the console, `gcloud` or a script | — |
| Point-in-time recovery (`POINT_IN_TIME_RECOVERY_ENABLED`) | Documents deleted or overwritten by a bug, a migration, a bad command | 7 days, to the minute |
| Terraform `deletion_policy = ABANDON` (provider default) | `terraform destroy` leaves the database alone | — |
| GCP project soft delete (platform default) | Deleting the whole project | 30 days |

**Not in place, on purpose:** scheduled Firestore backups, an export to a bucket in another
project, a lien on the project. So there is **no copy of the data outside the database
itself**: a deleted database or a project gone past 30 days is unrecoverable.

Check the live state (read-only, works with the observer account):

```bash
CLOUDSDK_CONFIG=$HOME/.config/shiori-observer/gcloud gcloud firestore databases describe --database='(default)' --project=shiori-polyforms --format='value(deleteProtectionState,pointInTimeRecoveryEnablement,earliestVersionTime,versionRetentionPeriod)'
```

`earliestVersionTime` is the oldest instant that can still be recovered.

## Before any recovery

1. **Stop the bleeding first.** If a bug or a migration is still writing, revert and deploy
   the fix (or pause the scheduler job) before restoring, or the restore is overwritten.
2. **Pin the instant.** Find the last whole minute *before* the damage, from Cloud Logging,
   the `migration-meta` collection or the deploy time. PITR snapshot times must be a whole
   minute (`…:05:00Z`) and later than `earliestVersionTime`. The clock runs: past seven days
   the version is gone, so do this the day the damage is seen.
3. **Scope the damage.** Which collections, which `userId`s, which documents. Collections are
   flat with a `userId` field, so a reader's library is one query.
4. Recovery writes production: it needs the user's own `gcloud` login (the observer account is
   read-only) and **the user's go-ahead**. It is never done silently.

## Case 1 — documents deleted or overwritten, less than 7 days ago

Never restore the whole database over `(default)`: it would erase every legitimate write made
since. Recover only what was damaged.

**A handful of documents** — read the old version straight from `(default)` with a read-only
transaction at a past `readTime`, then write it back:

```ts
import { Timestamp } from 'firebase-admin/firestore'

const readTime = Timestamp.fromDate(new Date('2026-10-19T14:05:00Z'))
const before = await db.runTransaction((tx) => tx.get(db.collection('books').doc(bookId)), {
  readOnly: true,
  readTime,
})
if (before.exists) await db.collection('books').doc(bookId).set(before.data()!)
```

A query works the same way (`tx.get(db.collection('books').where('userId', '==', userId))`).

**Many documents or whole collections** — clone the database at that instant into a
separate database, copy back what was damaged, then delete the clone:

```bash
gcloud firestore databases clone --project=shiori-polyforms --source-database='projects/shiori-polyforms/databases/(default)' --snapshot-time=2026-10-19T14:05:00Z --destination-database=recovered
```

Then a one-off script (in `scripts/`, run locally with the user's credentials) opens both
databases — `getFirestore(app)` and `getFirestore(app, 'recovered')` — and copies back the
damaged documents, in batches of at most 500 writes. A document deleted by the incident
exists in `recovered` and not in `(default)`; one created since the incident exists only in
`(default)` and must be left alone.

Delete the clone when done, it bills storage while it exists:

```bash
gcloud firestore databases delete --database=recovered --project=shiori-polyforms
```

If `clone` is refused (flag names change; check `gcloud firestore databases clone --help`),
the fallback is an export at the same instant into a bucket, then an import into a new
database: `gcloud firestore export gs://<bucket>/recovery --snapshot-time=… --database='(default)'`,
create `recovered`, `gcloud firestore import gs://<bucket>/recovery --database=recovered`.

## Case 2 — the `(default)` database deleted

Delete protection refuses this; someone has to turn it off first
(`gcloud firestore databases update --database='(default)' --no-delete-protection`, or the
console). If it happened anyway, the PITR history went with the database and **there is no
backup to restore from**. What is left is to recreate the database by applying Terraform
(the Deploy workflow) and to tell readers. Shared series catalogues rebuild themselves from
new scans; private books do not.

## Case 3 — the whole GCP project deleted

A deleted project stays in "pending deletion" for 30 days: everything is shut down, nothing is
erased. Restore it, with the user's own login (owner):

```bash
gcloud projects undelete shiori-polyforms
```

Then check billing is still linked (the prepaid Gemini key and Cloud Run need it), that Cloud
Run serves again, and that Firestore answers. APIs and services come back with the project;
re-run the Deploy workflow if anything is missing. Past 30 days the project, its data and its
ID are gone for good.

## If more protection is ever wanted

From cheapest to strongest: a lien on the project (free, blocks project deletion until
removed); a `google_firestore_backup_schedule` (daily kept 7 days, weekly kept 14 weeks,
billed as backup storage, restore into a new database); a scheduled export to a bucket in
another project with a retention lock — the only copy that survives losing the project.
