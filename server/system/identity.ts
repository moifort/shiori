import { getAuth } from 'firebase-admin/auth'

// The auth identity provider (Firebase Auth), kept separate from the Firestore
// module so the "Firestore only through repositories" boundary stays about data.
// getAuth() resolves the default app that ~/system/firebase initializes; the user
// repository imports both, so the app is always initialized before this runs.

// Delete the Firebase Auth user — the identity behind an account deletion.
// Idempotent: an already-absent user (a retried deletion) counts as done rather
// than an error, so the account wipe can be replayed safely after a partial failure.
export const deleteAuthUser = async (uid: string): Promise<void> => {
  try {
    await getAuth().deleteUser(uid)
  } catch (error) {
    if ((error as { code?: string }).code === 'auth/user-not-found') return
    throw error
  }
}
