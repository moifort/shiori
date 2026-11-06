package com.polyforms.shiori.features.onboarding

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.subscription.SubscriptionStore
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.reportError

/** Whether a signed-in reader goes to the onboarding or the app, read off the launch request. */
class OnboardingGate {
    sealed interface State {
        data object Loading : State
        data object Required : State
        data object Ready : State
        data class Failed(val message: String) : State
    }

    var state by mutableStateOf<State>(State.Loading)
        private set
    var isAdmin by mutableStateOf(false)
        private set
    var firstName by mutableStateOf<String?>(null)
        private set
    var avatar by mutableStateOf<AccountAvatar>(AccountAvatar.Initials)
        private set

    suspend fun refresh(subscriptions: SubscriptionStore, expectsNewReader: Boolean = false) {
        state = if (expectsNewReader) State.Required else State.Loading
        try {
            val launch = OnboardingApi.launch()
            isAdmin = launch.isAdmin
            if (state != State.Ready) {
                firstName = launch.firstName
                avatar = launch.avatar
                state = if (launch.onboardingCompleted) State.Ready else State.Required
            }
            subscriptions.start(launch.entitlement, launch.quota)
        } catch (error: Exception) {
            val message = reportError(error)
            if (!expectsNewReader) state = State.Failed(message)
        }
    }

    fun markCompleted(firstName: String, avatar: AccountAvatar) {
        this.firstName = firstName
        this.avatar = avatar
        state = State.Ready
    }

    fun showAvatar(avatar: AccountAvatar) {
        this.avatar = avatar
    }

    fun reset() {
        state = State.Loading
        isAdmin = false
        firstName = null
        avatar = AccountAvatar.Initials
    }
}

/** What the screens read of the account: its admin flag, first name and face. */
data class AccountEnvironment(
    val isAdmin: Boolean = false,
    val firstName: String? = null,
    val avatar: AccountAvatar = AccountAvatar.Initials,
    val showAvatar: (AccountAvatar) -> Unit = {},
)

val LocalAccount = androidx.compose.runtime.staticCompositionLocalOf { AccountEnvironment() }
