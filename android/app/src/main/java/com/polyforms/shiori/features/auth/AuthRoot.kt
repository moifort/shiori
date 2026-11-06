package com.polyforms.shiori.features.auth

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.polyforms.shiori.ContentView
import com.polyforms.shiori.features.onboarding.AccountEnvironment
import com.polyforms.shiori.features.onboarding.LocalAccount
import com.polyforms.shiori.features.onboarding.OnboardingGate
import com.polyforms.shiori.features.onboarding.OnboardingScreen
import com.polyforms.shiori.features.subscription.LocalSubscriptionStore
import com.polyforms.shiori.features.subscription.SubscriptionStore
import com.polyforms.shiori.shared.AuthEvents
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import com.polyforms.shiori.shared.services.AppSupportGate
import com.polyforms.shiori.shared.shell.CoverVeil
import com.polyforms.shiori.shared.shell.CoverWall
import com.polyforms.shiori.shared.shell.LaunchCurtainHost
import com.polyforms.shiori.shared.shell.OpeningProgress
import com.polyforms.shiori.shared.shell.UpdateRequiredView

/**
 * The root: the update gate, the sign-in over the cover wall, the onboarding, then the app,
 * under the launch curtain until the launch request answered.
 */
@Composable
fun AuthRoot() {
    val context = LocalContext.current
    val session = remember { AuthSession() }
    val gate = remember { OnboardingGate() }
    val support = remember { AppSupportGate() }
    val subscriptions = remember { SubscriptionStore(context) }
    val showcase = Showcase.isOn

    LaunchedEffect(Unit) {
        AuthEvents.onAccountMayBeGone = { AuthSession.dropSessionIfAccountIsGone() }
        if (!showcase) support.check()
    }
    val scope = rememberCoroutineScope()
    // Back to the front: the floor may have been raised meanwhile.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { if (!showcase) scope.launch { support.check() } }
    LaunchedEffect(session.user?.uid) {
        if (session.user != null || showcase) gate.refresh(subscriptions, session.isFirstAuthorization) else gate.reset()
    }

    val update = support.state as? AppSupportGate.State.UpdateRequired
    val route = if (gate.state == OnboardingGate.State.Loading && session.isFirstAuthorization) OnboardingGate.State.Required else gate.state
    val showsWall = update == null && !showcase && (session.user == null || gate.state == OnboardingGate.State.Loading || gate.state == OnboardingGate.State.Required)

    CompositionLocalProvider(
        LocalAuthSession provides session,
        LocalSubscriptionStore provides subscriptions,
        LocalAccount provides AccountEnvironment(gate.isAdmin, gate.firstName, gate.avatar, gate::showAvatar),
    ) {
        LaunchCurtainHost(ready = session.user == null || gate.state != OnboardingGate.State.Loading) {
            Box(Modifier.fillMaxSize()) {
                if (showsWall) CoverWall()
                when {
                    update != null -> UpdateRequiredView(update.storeURL)
                    session.user == null && !showcase -> ShioriTheme(dark = true) { LoginScreen() }
                    else -> when (route) {
                        OnboardingGate.State.Loading -> ShioriTheme(dark = true) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                CoverVeil(covering = true)
                                OpeningProgress(L("Préparation de votre bibliothèque…"))
                            }
                        }
                        OnboardingGate.State.Required -> ShioriTheme(dark = true) {
                            OnboardingScreen(onCompleted = { name, avatar -> gate.markCompleted(name, avatar) })
                        }
                        OnboardingGate.State.Ready -> Box(Modifier.fillMaxSize()) {
                            ContentView()
                            if (com.polyforms.shiori.features.home.LibraryPreparation.isActive) {
                                ShioriTheme(dark = true) {
                                    Box(Modifier.fillMaxSize()) {
                                        CoverVeil(covering = true)
                                        com.polyforms.shiori.features.home.LibraryPreparationView()
                                    }
                                }
                            }
                        }
                        is OnboardingGate.State.Failed -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            FailureState(L("Connexion impossible"), route.message) { gate.refresh(subscriptions) }
                        }
                    }
                }
            }
        }
    }
}
