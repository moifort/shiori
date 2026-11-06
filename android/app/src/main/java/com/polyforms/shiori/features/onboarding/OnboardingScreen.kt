package com.polyforms.shiori.features.onboarding

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.auth.LocalAuthSession
import com.polyforms.shiori.features.home.LibraryPreparation
import com.polyforms.shiori.features.import.AmazonLogin
import com.polyforms.shiori.features.import.AmazonMarketplace
import com.polyforms.shiori.features.import.BackgroundSync
import com.polyforms.shiori.features.import.ImportApi
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.import.KindleApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.AppScope
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.organisms.AvatarPickerSheet
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.AmazonSignInSheet
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.shell.CoverVeil
import com.polyforms.shiori.shared.track
import kotlinx.coroutines.launch

/** What the onboarding asks of the server. */
interface OnboardingClient {
    suspend fun complete(firstName: String)
    suspend fun changeAvatar(avatar: AccountAvatar): AccountAvatar
    suspend fun startSignIn(source: ImportSource, marketplace: AmazonMarketplace): AmazonLogin
    suspend fun completeSignIn(source: ImportSource, code: String)
    fun beginPreparation(sources: List<ImportSource>)

    companion object {
        val live: OnboardingClient = object : OnboardingClient {
            override suspend fun complete(firstName: String) = OnboardingApi.completeOnboarding(firstName)
            override suspend fun changeAvatar(avatar: AccountAvatar) = OnboardingApi.changeAvatar(avatar)
            override suspend fun startSignIn(source: ImportSource, marketplace: AmazonMarketplace) =
                if (source == ImportSource.AUDIBLE) ImportApi.startSignIn(marketplace) else KindleApi.startSignIn(marketplace)
            override suspend fun completeSignIn(source: ImportSource, code: String) {
                if (source == ImportSource.AUDIBLE) {
                    ImportApi.completeSignIn(code)
                    BackgroundSync.audible.start(AppScope)
                } else {
                    KindleApi.completeSignIn(code)
                    BackgroundSync.kindle.start(AppScope)
                }
            }
            override fun beginPreparation(sources: List<ImportSource>) = LibraryPreparation.begin(sources)
        }
    }
}

private enum class OnboardingStep { FIRST_NAME, LIBRARIES }

/** A new reader's first steps: their first name and face, then the libraries to connect. */
@Composable
fun OnboardingScreen(onCompleted: (String, AccountAvatar) -> Unit, client: OnboardingClient = OnboardingClient.live) {
    val scope = rememberCoroutineScope()
    val session = LocalAuthSession.current
    var step by remember { mutableStateOf(OnboardingStep.FIRST_NAME) }
    var firstName by remember { mutableStateOf(session.suggestedFirstName ?: "") }
    var avatar by remember { mutableStateOf<AccountAvatar>(AccountAvatar.Tinted(AvatarColor.entries.random())) }
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var connectsAudible by remember { mutableStateOf(false) }
    var connectsKindle by remember { mutableStateOf(false) }
    var marketplace by remember { mutableStateOf(AmazonMarketplace.suggested) }
    val pending = remember { mutableListOf<ImportSource>() }
    val linked = remember { mutableListOf<ImportSource>() }
    var signingIn by remember { mutableStateOf<ImportSource?>(null) }
    var signIn by remember { mutableStateOf<AmazonLogin?>(null) }
    var isConnecting by remember { mutableStateOf(false) }
    var connectionError by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { track(AnalyticsEvent.OnboardingStarted) }

    fun enterApp() {
        client.beginPreparation(linked.toList())
        onCompleted(firstName.trim(), avatar)
    }
    suspend fun connectNext() {
        if (pending.isEmpty()) {
            signingIn = null
            enterApp()
            return
        }
        val source = pending.removeAt(0)
        signingIn = source
        isConnecting = true
        try {
            signIn = client.startSignIn(source, marketplace)
        } catch (failure: Exception) {
            connectionError = reportError(failure)
        } finally {
            isConnecting = false
        }
    }
    suspend fun finishSignIn(code: String) {
        signIn = null
        val source = signingIn ?: return
        isConnecting = true
        try {
            client.completeSignIn(source, code)
            linked += source
        } catch (failure: Exception) {
            isConnecting = false
            connectionError = reportError(failure)
            return
        }
        isConnecting = false
        connectNext()
    }
    suspend fun complete() {
        val name = firstName.trim()
        if (name.isEmpty()) return
        isSaving = true
        try {
            client.complete(name)
            track(AnalyticsEvent.OnboardingCompleted)
            if (avatar != AccountAvatar.Initials) {
                avatar = try {
                    client.changeAvatar(avatar)
                } catch (failure: Exception) {
                    reportError(failure)
                    AccountAvatar.Initials
                }
            }
            step = OnboardingStep.LIBRARIES
        } catch (failure: Exception) {
            error = reportError(failure)
        } finally {
            isSaving = false
        }
    }

    Box(Modifier.fillMaxSize()) {
        CoverVeil(covering = true)
        Box(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding().padding(16.dp)) {
            when (step) {
                OnboardingStep.FIRST_NAME -> FirstNamePage(firstName, { firstName = it }, avatar, { avatar = it }) { scope.launch { complete() } }
                OnboardingStep.LIBRARIES -> LibrariesOfferPage(
                    connectsAudible, { connectsAudible = it },
                    connectsKindle, { connectsKindle = it },
                    marketplace, { marketplace = it },
                    isConnecting,
                    onConnect = {
                        pending.clear()
                        if (connectsAudible) pending += ImportSource.AUDIBLE
                        if (connectsKindle) pending += ImportSource.KINDLE
                        scope.launch { connectNext() }
                    },
                    onSkip = ::enterApp,
                )
            }
        }
        if (isSaving) CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
    }
    signIn?.let { login ->
        AmazonSignInSheet(login, onCode = { scope.launch { finishSignIn(it) } }, onCancel = {
            signIn = null
            scope.launch { connectNext() }
        })
    }
    connectionError?.let { message ->
        ShioriAlert(L("Connexion impossible"), L("%@ Vous pourrez réessayer depuis les réglages.", message), onDismiss = {
            connectionError = null
            scope.launch { connectNext() }
        })
    }
    error?.let { ShioriAlert(L("Impossible de terminer"), it, onDismiss = { error = null }) }
}

@Composable
private fun Entrance(delay: Int, content: @Composable () -> Unit) {
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    val progress by animateFloatAsState(if (shown) 1f else 0f, tween(450, delayMillis = delay), label = "entrance")
    Box(Modifier.graphicsLayer { alpha = progress; translationY = (1 - progress) * 40f }) { content() }
}

/** "Comment vous appelez-vous ?": the first name friends will see, and the face. */
@Composable
private fun FirstNamePage(firstName: String, onFirstName: (String) -> Unit, avatar: AccountAvatar, onAvatar: (AccountAvatar) -> Unit, onNext: () -> Unit) {
    var picking by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val trimmed = firstName.trim()
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Entrance(0) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Box(Modifier.plainClickable { picking = true }) {
                    AccountAvatarView(avatar, trimmed, 112.dp)
                    Box(Modifier.align(Alignment.BottomEnd).size(34.dp).background(Color.White.copy(alpha = 0.2f), CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Symbol("pencil"), L("Modifier l'avatar"), Modifier.size(15.dp), tint = Color.White)
                    }
                }
            }
        }
        Entrance(40) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(L("Comment vous appelez-vous ?"), style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = Color.White)
                Text(L("C'est le prénom que vos amis verront lors d'un partage."), style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.6f))
            }
        }
        Entrance(80) {
            PlainTextField(
                firstName,
                onFirstName,
                L("Prénom"),
                Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.14f), RoundedCornerShape(14.dp)).padding(16.dp),
                capitalization = KeyboardCapitalization.Words,
                focusRequester = focus,
                onDone = { if (trimmed.isNotEmpty()) onNext() },
            )
        }
        Spacer(Modifier.weight(1f))
        Entrance(160) { ShioriButton(L("Continuer"), tint = Color.White, enabled = trimmed.isNotEmpty(), large = true, fillWidth = true, foreground = Color.Black) { onNext() } }
    }
    if (picking) AvatarPickerSheet(avatar, trimmed, { picking = false }, onAvatar)
}

/** "Vos bibliothèques": Audible and Kindle to connect, the store, now or later. */
@Composable
private fun LibrariesOfferPage(
    audible: Boolean,
    onAudible: (Boolean) -> Unit,
    kindle: Boolean,
    onKindle: (Boolean) -> Unit,
    marketplace: AmazonMarketplace,
    onMarketplace: (AmazonMarketplace) -> Unit,
    isWorking: Boolean,
    onConnect: () -> Unit,
    onSkip: () -> Unit,
) {
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Entrance(0) {
            Box(Modifier.size(88.dp).background(Shiori.colors.orange, RoundedCornerShape(22.dp)), contentAlignment = Alignment.Center) {
                Icon(Symbol("books.vertical.fill"), null, Modifier.size(44.dp), tint = Color.White)
            }
        }
        Entrance(80) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(L("Vos bibliothèques"), style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = Color.White)
                Text(
                    L("Connectez celles que vous utilisez : elles sont importées pendant que vous découvrez l'application, puis suivies chaque nuit. Vous pourrez aussi le faire plus tard depuis les réglages."),
                    style = Shiori.type.subheadline,
                    color = Color.White.copy(alpha = 0.6f),
                )
            }
        }
        Entrance(120) {
            Column(Modifier.background(Shiori.colors.secondaryGroupedBackground, RoundedCornerShape(12.dp)).padding(horizontal = 12.dp).alpha(if (isWorking) 0.6f else 1f)) {
                SourceToggle("headphones", "Audible", L("Vos livres audio, avec ce que vous avez déjà écouté."), audible, onAudible)
                ShioriDivider(Modifier.padding(start = 44.dp))
                SourceToggle("book.closed", "Kindle", L("Vos livres numériques, avec ceux que vous avez finis."), kindle, onKindle)
                ShioriDivider(Modifier.padding(start = 44.dp))
                MenuPicker(marketplace, AmazonMarketplace.entries, { it.amazonLabel }, onMarketplace, divider = false) {
                    Text(L("Boutique"), style = Shiori.type.body, color = Shiori.colors.label)
                }
            }
        }
        Spacer(Modifier.weight(1f))
        Entrance(160) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ShioriButton(L("Connecter"), symbol = "arrow.down.circle", tint = Color.White, enabled = !isWorking && (audible || kindle), large = true, fillWidth = true, foreground = Color.Black) { onConnect() }
                ShioriButton(L("Plus tard"), kind = ButtonKind.BORDERED, tint = Color.White, enabled = !isWorking, large = true, fillWidth = true) { onSkip() }
            }
        }
    }
}

@Composable
private fun SourceToggle(symbol: String, title: String, detail: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol(symbol), null, Modifier.size(24.dp), tint = Shiori.colors.accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Shiori.type.body, color = Shiori.colors.label)
            Text(detail, style = Shiori.type.caption, color = Shiori.colors.secondaryLabel)
        }
        ShioriSwitch(isOn, onChange)
    }
}
