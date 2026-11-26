package com.polyforms.shiori.features.onboarding.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.onboarding.OnboardingLibrary
import com.polyforms.shiori.features.onboarding.OnboardingLibrarySteps.Phase
import com.polyforms.shiori.features.onboarding.components.molecules.LibraryFactList
import com.polyforms.shiori.features.onboarding.components.molecules.LibraryLogoTile
import com.polyforms.shiori.features.onboarding.components.molecules.OnboardingStepProgress
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.ActionSize
import com.polyforms.shiori.shared.components.styles.Shiori

/**
 * One library's step in the onboarding, in three states. Before any sign-in it says which service
 * it is, what Shiori brings in from it and what it leaves alone, so the reader knows what Amazon's
 * page is for before it opens; then it confirms the connection, or says it failed. Pure.
 */
@Composable
fun LibraryStepPage(
    library: OnboardingLibrary,
    number: Int,
    count: Int,
    phase: Phase = Phase.INTRO,
    next: OnboardingLibrary? = null,
    isWorking: Boolean = false,
    onPrimary: () -> Unit,
    onSecondary: () -> Unit,
) {
    val colors = Shiori.colors
    val title = when (phase) {
        Phase.INTRO -> library.title
        Phase.CONNECTED -> library.doneTitle
        Phase.FAILED -> library.failedTitle
    }
    val summary = when (phase) {
        Phase.INTRO -> library.summary
        Phase.CONNECTED -> library.doneSummary
        Phase.FAILED -> L("La page d'Amazon n'a pas pu terminer la connexion. Vous pouvez réessayer maintenant, ou plus tard depuis les réglages.")
    }
    val primary = when (phase) {
        Phase.INTRO -> library.connectLabel
        Phase.CONNECTED -> OnboardingLibrary.continueLabel(next)
        Phase.FAILED -> L("Réessayer")
    }
    val secondary = when (phase) {
        Phase.INTRO -> L("Plus tard")
        Phase.CONNECTED -> null
        Phase.FAILED -> OnboardingLibrary.skipLabel(next)
    }
    Column(Modifier.fillMaxSize()) {
        OnboardingStepProgress(number, count, Modifier.padding(horizontal = 4.dp, vertical = 8.dp))
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 4.dp).padding(bottom = 24.dp)) {
            Box(Modifier.padding(top = 18.dp)) { LibraryLogoTile(library, isDone = phase == Phase.CONNECTED) }
            Text(title, style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.padding(top = 16.dp))
            Text(summary, style = Shiori.type.subheadline, color = colors.secondaryLabel, modifier = Modifier.padding(top = 8.dp))
            when (phase) {
                Phase.INTRO -> {
                    Section(L("Ce que Shiori récupère"), library.brings)
                    Section(L("Ce que Shiori ne fait pas"), library.leaves)
                    if (library == OnboardingLibrary.KINDLE) {
                        Text(
                            L("Amazon vous redemande de vous connecter, même avec le compte d'Audible."),
                            style = Shiori.type.footnote,
                            color = colors.secondaryLabel,
                            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp),
                        )
                    }
                }
                Phase.CONNECTED -> LibraryFactList(library.done, Modifier.padding(top = 18.dp))
                Phase.FAILED -> LibraryFactList(
                    listOf(OnboardingLibrary.Fact("lock", L("Rien n'a été gardé"), L("Aucune donnée de votre compte n'est restée dans Shiori."))),
                    Modifier.padding(top = 18.dp),
                )
            }
        }
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ActionButton(onPrimary, Modifier.fillMaxWidth(), size = ActionSize.LARGE, spansWidth = true, enabled = !isWorking) {
                Box(contentAlignment = Alignment.Center) {
                    Box(Modifier.graphicsLayer { alpha = if (isWorking) 0f else 1f }) { ActionLabel(primary, null, ActionSize.LARGE.side) }
                    if (isWorking) CircularProgressIndicator(Modifier.size(20.dp), color = Color.Black, strokeWidth = 2.dp)
                }
            }
            if (secondary != null) {
                ActionButton(onSecondary, Modifier.fillMaxWidth(), fill = ActionFill.GLASS, size = ActionSize.LARGE, spansWidth = true, enabled = !isWorking) {
                    ActionLabel(secondary, null, ActionSize.LARGE.side)
                }
            }
        }
    }
}

@Composable
private fun Section(header: String, facts: List<OnboardingLibrary.Fact>) {
    Column(Modifier.padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(header, style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel, modifier = Modifier.padding(horizontal = 16.dp))
        LibraryFactList(facts)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000, heightDp = 852)
@Composable
private fun LibraryStepPagePreview() = PreviewSurface(dark = true) {
    Box(Modifier.padding(16.dp)) {
        LibraryStepPage(OnboardingLibrary.KINDLE, 2, 3, next = OnboardingLibrary.GOODREADS, onPrimary = {}, onSecondary = {})
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000, heightDp = 852)
@Composable
private fun LibraryStepPageConnectedPreview() = PreviewSurface(dark = true) {
    Box(Modifier.padding(16.dp)) {
        LibraryStepPage(OnboardingLibrary.AUDIBLE, 1, 3, Phase.CONNECTED, OnboardingLibrary.KINDLE, onPrimary = {}, onSecondary = {})
    }
}
