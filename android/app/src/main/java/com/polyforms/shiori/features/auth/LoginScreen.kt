package com.polyforms.shiori.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.polyforms.shiori.BuildConfig
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.shell.CoverVeil
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/** The sign-in: Google's account picker, its token handed to Firebase. Apple stays on iOS. */
@Composable
fun LoginScreen() {
    val session = LocalAuthSession.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var signingIn by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LoginPage(signingIn, error) {
        error = null
        signingIn = true
        scope.launch {
            try {
                val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID).build()
                val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                val result = CredentialManager.create(context).getCredential(context, request)
                val credential = result.credential
                if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    error = L("Google n'a pas renvoyé de jeton.")
                    return@launch
                }
                val google = GoogleIdTokenCredential.createFrom(credential.data)
                // Before signing in: the session turns signed-in the moment Firebase answers,
                // and the onboarding reads the name on appearing.
                session.rememberGoogleName(google.givenName)
                FirebaseAuth.getInstance().signInWithCredential(GoogleAuthProvider.getCredential(google.idToken, null)).await()
            } catch (_: GetCredentialCancellationException) {
                // The reader closed Google's sheet: nothing went wrong.
            } catch (failure: Exception) {
                error = failure.localizedMessage
            } finally {
                signingIn = false
            }
        }
    }
}

/** What the sign-in shows over the cover wall. */
@Composable
fun LoginPage(isSigningIn: Boolean, error: String?, onSignIn: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        CoverVeil()
        Column(
            Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))
            Text(L("Tous vos livres,\nau même endroit"), style = Shiori.type.largeTitle, color = Color.White, textAlign = TextAlign.Center)
            Text(
                L("Une photo de la couverture suffit."),
                style = Shiori.type.body,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 10.dp),
            )
            Row(
                Modifier
                    .padding(top = 32.dp)
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(CircleShape)
                    .background(Color.White)
                    .plainClickable(enabled = !isSigningIn, onClick = onSignIn),
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (isSigningIn) {
                    CircularProgressIndicator(Modifier.size(22.dp), color = Color.Black, strokeWidth = 2.dp)
                } else {
                    Text("G", style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color(0xFF4285F4))
                    Text(L("Continuer avec Google"), style = Shiori.type.headline, color = Color.Black)
                }
            }
            if (error != null) {
                Text(error, style = Shiori.type.footnote, color = Shiori.colors.red, modifier = Modifier.padding(top = 12.dp), textAlign = TextAlign.Center)
            }
        }
    }
}
