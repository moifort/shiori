package com.polyforms.shiori.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.import.BackgroundSync
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import kotlinx.coroutines.delay

/** The checklist shown between the onboarding and the Home, while the first libraries come in. */
object LibraryPreparation {
    var isActive by mutableStateOf(false)
        private set
    var sources by mutableStateOf<List<ImportSource>>(emptyList())
        private set
    var loadHome: (suspend () -> Boolean)? = null

    fun begin(linking: List<ImportSource>) {
        sources = linking
        isActive = true
    }

    fun finish() {
        isActive = false
    }
}

enum class PreparationState { WAITING, WORKING, DONE, CONTINUING, FAILED }

private sealed interface Step {
    data object Profile : Step
    data object WelcomeScans : Step
    data class Library(val source: ImportSource) : Step
    data object Home : Step
}

/** "Préparation de votre bibliothèque": the profile, the welcome scans, each library, the Home. */
@Composable
fun LibraryPreparationView() {
    val steps = remember { listOf(Step.Profile, Step.WelcomeScans) + LibraryPreparation.sources.map(Step::Library) + Step.Home }
    var current by remember { mutableIntStateOf(0) }
    val outcomes = remember { mutableStateMapOf<Step, PreparationState>() }
    LaunchedEffect(Unit) {
        val deadline = System.currentTimeMillis() + 25_000
        suspend fun pass(sync: BackgroundSync): PreparationState {
            while (sync.isSyncing && System.currentTimeMillis() < deadline) delay(300)
            if (sync.isSyncing) return PreparationState.CONTINUING
            return if (sync.errorMessage == null) PreparationState.DONE else PreparationState.FAILED
        }
        steps.forEachIndexed { index, step ->
            current = index
            outcomes[step] = when (step) {
                Step.Profile, Step.WelcomeScans -> PreparationState.DONE
                is Step.Library -> pass(if (step.source == ImportSource.AUDIBLE) BackgroundSync.audible else BackgroundSync.kindle)
                Step.Home -> if (LibraryPreparation.loadHome?.invoke() == true) PreparationState.DONE else PreparationState.FAILED
            }
            delay(700)
        }
        LibraryPreparation.finish()
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(L("Préparation de votre bibliothèque"), style = Shiori.type.headline, color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 20.dp))
        val shape = RoundedCornerShape(26.dp)
        Column(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.1f), shape).border(0.5.dp, Color.White.copy(alpha = 0.2f), shape).padding(horizontal = 18.dp, vertical = 4.dp)) {
            steps.forEachIndexed { index, step ->
                if (index > 0) ShioriDivider()
                val state = outcomes[step] ?: if (index == current) PreparationState.WORKING else PreparationState.WAITING
                val label = when (step) {
                    Step.Profile -> L("Votre profil")
                    Step.WelcomeScans -> L("Vos scans de bienvenue")
                    is Step.Library -> if (step.source == ImportSource.AUDIBLE) L("Votre bibliothèque Audible") else L("Votre bibliothèque Kindle")
                    Step.Home -> L("Votre accueil")
                }
                Row(Modifier.padding(vertical = 13.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
                        when (state) {
                            PreparationState.WAITING -> Icon(Symbol("circle"), null, Modifier.size(22.dp), tint = Color.White.copy(alpha = 0.3f))
                            PreparationState.WORKING -> CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                            PreparationState.DONE -> Icon(Symbol("checkmark.circle.fill"), L("Terminé"), Modifier.size(22.dp), tint = Color.White)
                            PreparationState.CONTINUING -> Icon(Symbol("clock"), null, Modifier.size(20.dp), tint = Color.White)
                            PreparationState.FAILED -> Icon(Symbol("exclamationmark.circle"), L("Échec"), Modifier.size(20.dp), tint = Color.White)
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(label, style = Shiori.type.body.copy(fontWeight = FontWeight.SemiBold), color = Color.White, modifier = Modifier.alpha(if (state == PreparationState.WAITING) 0.4f else 1f))
                        when (state) {
                            PreparationState.CONTINUING -> Text(L("Se poursuit en arrière-plan"), style = Shiori.type.footnote, color = Color.White.copy(alpha = 0.6f))
                            PreparationState.FAILED -> Text(L("Vous pourrez réessayer depuis les réglages"), style = Shiori.type.footnote, color = Color.White.copy(alpha = 0.6f))
                            else -> Unit
                        }
                    }
                }
            }
        }
    }
}
