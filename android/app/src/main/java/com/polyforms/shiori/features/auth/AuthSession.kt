package com.polyforms.shiori.features.auth

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseUser
import com.polyforms.shiori.features.search.RecentSearches
import com.polyforms.shiori.features.search.RecentlyViewed
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.SnapshotCaches
import io.sentry.Sentry
import io.sentry.protocol.User
import kotlinx.coroutines.tasks.await

/**
 * Who is signed in, as Firebase says. Signing out — or an account deleted elsewhere — forgets
 * every snapshot, so the next reader never sees the last one's library.
 */
class AuthSession {
    private val auth: FirebaseAuth? = if (FirebaseApp.getApps(AppContext.get()).isEmpty()) null else FirebaseAuth.getInstance()

    var user by mutableStateOf<FirebaseUser?>(auth?.currentUser)
        private set

    /** The given name Google handed over at the first sign-in, for the onboarding's field. */
    var googleGivenName by mutableStateOf<String?>(null)
        private set

    val isFirstAuthorization: Boolean get() = googleGivenName != null

    val suggestedFirstName: String?
        get() = googleGivenName ?: user?.displayName?.split(" ")?.firstOrNull()?.takeIf { it.isNotBlank() }

    init {
        report(user)
        auth?.addAuthStateListener { firebase ->
            val next = firebase.currentUser
            if (user != null && next == null) forgetAccount()
            user = next
            report(next)
        }
    }

    private fun report(user: FirebaseUser?) {
        if (Sentry.isEnabled()) Sentry.setUser(user?.let { User().apply { id = it.uid } })
    }

    fun rememberGoogleName(givenName: String?) {
        googleGivenName = givenName?.trim()?.ifEmpty { null }
    }

    fun signOut() {
        auth?.signOut()
    }

    private fun forgetAccount() {
        googleGivenName = null
        SnapshotCaches.clear()
        RecentSearches().clear()
        RecentlyViewed().clear()
        com.polyforms.shiori.features.search.LibrarySearchIndex.shared.forget()
    }

    companion object {
        /** Signs out when the server refused a token because the account behind it is gone. */
        suspend fun dropSessionIfAccountIsGone(): Boolean {
            if (FirebaseApp.getApps(AppContext.get()).isEmpty()) return false
            val user = FirebaseAuth.getInstance().currentUser ?: return false
            return try {
                user.reload().await()
                false
            } catch (_: FirebaseAuthInvalidUserException) {
                FirebaseAuth.getInstance().signOut()
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}

val LocalAuthSession = staticCompositionLocalOf<AuthSession> { error("No AuthSession") }
