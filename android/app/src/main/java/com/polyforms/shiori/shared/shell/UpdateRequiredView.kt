package com.polyforms.shiori.shared.shell

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.EmptyStateAction

/** This build no longer works with the server: the way to the Play Store. */
@Composable
fun UpdateRequiredView(storeURL: String) {
    val uri = LocalUriHandler.current
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        EmptyState(
            "arrow.down.app",
            L("Mise à jour requise"),
            L("Cette version de Shiori n'est plus compatible avec le serveur. La dernière version est disponible sur Google Play."),
            primary = EmptyStateAction(L("Mettre à jour")) { uri.openUri(storeURL) },
        )
    }
}
