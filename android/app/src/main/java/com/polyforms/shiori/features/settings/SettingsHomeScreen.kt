package com.polyforms.shiori.features.settings

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.polyforms.shiori.BuildConfig
import com.polyforms.shiori.features.auth.AuthSession
import com.polyforms.shiori.features.auth.LocalAuthSession
import com.polyforms.shiori.features.import.AudibleImportScreen
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.import.KindleImportScreen
import com.polyforms.shiori.features.onboarding.LocalAccount
import com.polyforms.shiori.features.onboarding.OnboardingApi
import com.polyforms.shiori.features.settings.components.pages.ChangelogPage
import com.polyforms.shiori.features.settings.components.pages.FeedbackSheet
import com.polyforms.shiori.features.settings.components.pages.NotificationSettingsAction
import com.polyforms.shiori.features.settings.components.pages.NotificationSettingsPage
import com.polyforms.shiori.features.settings.components.pages.ProfileSettingsAction
import com.polyforms.shiori.features.settings.components.pages.ProfileSettingsPage
import com.polyforms.shiori.features.settings.components.pages.SettingsDestination
import com.polyforms.shiori.features.settings.components.pages.SettingsHomeAction
import com.polyforms.shiori.features.settings.components.pages.SettingsHomePage
import com.polyforms.shiori.features.subscription.LocalSubscriptionStore
import com.polyforms.shiori.features.subscription.components.pages.PremiumSheet
import com.polyforms.shiori.features.subscription.components.pages.PremiumTrigger
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.NotificationAuthorization
import com.polyforms.shiori.shared.PushRegistrar
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.sendFeedback
import kotlinx.coroutines.launch

/** The settings, connected: each page they open, the offer, a word to us. */
@Composable
fun SettingsHomeScreen() {
    val navigator = currentNavigator
    val store = LocalSubscriptionStore.current
    val session = LocalAuthSession.current
    var premium by remember { mutableStateOf(false) }
    var feedback by remember { mutableStateOf(false) }
    var blocked by remember { mutableStateOf(PushRegistrar.authorization() == NotificationAuthorization.DENIED) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { blocked = PushRegistrar.authorization() == NotificationAuthorization.DENIED }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        SettingsHomePage(session.user?.displayName ?: session.user?.email, store.isPremium, blocked, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toString()) { action ->
            when (action) {
                is SettingsHomeAction.Open -> navigator.push {
                    when (action.destination) {
                        SettingsDestination.PROFILE -> ProfileSettingsScreen()
                        SettingsDestination.NOTIFICATIONS -> NotificationSettingsScreen()
                        SettingsDestination.CHANGELOG -> ChangelogScreen()
                    }
                }
                SettingsHomeAction.ShowPremium -> premium = true
                SettingsHomeAction.ShowFeedback -> feedback = true
                is SettingsHomeAction.OpenSource -> navigator.push {
                    when (action.source) {
                        ImportSource.AUDIBLE -> AudibleImportScreen { navigator.pop() }
                        ImportSource.KINDLE -> KindleImportScreen { navigator.pop() }
                    }
                }
            }
        }
        ScreenBar(title = L("Réglages"))
    }
    if (premium) PremiumSheet(PremiumTrigger.DISCOVER) { premium = false }
    if (feedback) FeedbackSheet({ feedback = false }, ::sendFeedback)
}

/** The account page, connected. */
@Composable
fun ProfileSettingsScreen() {
    val scope = rememberCoroutineScope()
    val session = LocalAuthSession.current
    val account = LocalAccount.current
    var saving by remember { mutableStateOf<AccountAvatar?>(null) }
    var deleting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        ProfileSettingsPage(
            account.firstName,
            saving ?: account.avatar,
            saving != null,
            session.user?.displayName,
            (session.user?.uid ?: "").take(8),
            deleting,
            error,
        ) { action ->
            scope.launch {
                when (action) {
                    is ProfileSettingsAction.ChangeAvatar -> {
                        saving = action.avatar
                        error = null
                        try {
                            account.showAvatar(OnboardingApi.changeAvatar(action.avatar))
                        } catch (failure: Exception) {
                            error = reportError(failure)
                        } finally {
                            saving = null
                        }
                    }
                    ProfileSettingsAction.SignOut -> {
                        error = null
                        PushRegistrar.forgetDevice()
                        session.signOut()
                    }
                    ProfileSettingsAction.DeleteAccount -> {
                        deleting = true
                        error = null
                        try {
                            SettingsApi.deleteAccount()
                        } catch (failure: Exception) {
                            if (AuthSession.dropSessionIfAccountIsGone()) return@launch
                            error = reportError(failure)
                            deleting = false
                            return@launch
                        }
                        session.signOut()
                    }
                }
            }
        }
        ScreenBar(title = L("Profil"))
    }
}

/** The alerts page, connected: the server's switches and the phone's permission. */
@Composable
fun NotificationSettingsScreen() {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var settings by remember { mutableStateOf<NotificationSettings?>(null) }
    var authorization by remember { mutableStateOf(PushRegistrar.authorization()) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        try {
            settings = NotificationsApi.settings()
        } catch (failure: Exception) {
            error = reportError(failure)
        }
    }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { authorization = PushRegistrar.authorization() }
    suspend fun set(kinds: List<AlertKind>, enabled: Boolean) {
        val before = settings ?: return
        val changed = kinds.filter { (it in before.enabled) != enabled }
        if (changed.isEmpty()) return
        settings = before.copy(enabled = if (enabled) before.enabled + changed else before.enabled - changed.toSet())
        saving = true
        try {
            if (enabled) {
                PushRegistrar.requestPermission()
                authorization = PushRegistrar.authorization()
            }
            for (kind in changed) settings = NotificationsApi.setAlert(kind, enabled)
        } catch (failure: Exception) {
            settings = before
            error = reportError(failure)
        } finally {
            saving = false
        }
    }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        NotificationSettingsPage(settings, authorization == NotificationAuthorization.DENIED, error, saving) { action ->
            when (action) {
                is NotificationSettingsAction.Set -> scope.launch { set(listOf(action.kind), action.enabled) }
                is NotificationSettingsAction.SilenceAll -> scope.launch { set(AlertKind.entries, !action.silenced) }
                NotificationSettingsAction.OpenSystemSettings -> context.startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }
        }
        ScreenBar(title = L("Notifications"))
    }
}

/** The release notes, connected. */
@Composable
fun ChangelogScreen() {
    var entries by remember { mutableStateOf<List<ChangelogEntry>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    suspend fun load() {
        loading = true
        error = null
        try {
            entries = SettingsApi.changelog()
        } catch (failure: Exception) {
            error = reportError(failure)
        } finally {
            loading = false
        }
    }
    LaunchedEffect(Unit) { load() }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        ChangelogPage(entries, loading, error) { load() }
        ScreenBar(title = L("Nouveautés"))
    }
}
