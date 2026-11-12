package com.polyforms.shiori.features.scan.components.organisms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.EmptyStateAction
import com.polyforms.shiori.shared.components.organisms.AIGlassDrops
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A darkened veil over the camera with a cover-shaped hole and its white rim. */
@Composable
fun ViewfinderOverlay(leavesRoomForShutter: Boolean = true) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val height = minOf(maxWidth * 0.88f * 1.5f, maxHeight * if (leavesRoomForShutter) 0.64f else 0.84f)
        val width = height / 1.5f
        Canvas(Modifier.fillMaxSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            drawRect(Color.Black.copy(alpha = 0.4f))
            val w = width.toPx()
            val h = height.toPx()
            val origin = Offset((size.width - w) / 2, (size.height - h) / 2)
            drawRoundRect(Color.White, origin, Size(w, h), CornerRadius(20.dp.toPx()), blendMode = BlendMode.Clear)
        }
        Box(Modifier.align(Alignment.Center).size(width, height).border(3.dp, Color.White.copy(alpha = 0.8f), RoundedCornerShape(20.dp)))
    }
}

/** The shutter: a white disc in a white ring. */
@Composable
fun Shutter(size: Dp = 72.dp, onClick: () -> Unit) {
    Box(Modifier.size(size).border(4.dp, Color.White, CircleShape).padding(size / 12).plainClickable(onClick = onClick)) {
        Box(Modifier.fillMaxSize().background(Color.White, CircleShape))
    }
}

/** The AI reading the cover. */
@Composable
fun ScanAnalyzingPage() {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(40.dp, Alignment.CenterVertically)) {
        AIGlassDrops()
        Text(L("Analyse de la couverture"), style = Shiori.type.headline, color = Shiori.colors.label)
    }
}

/** No book on the photo: try again, or add it by hand. */
@Composable
fun ScanNoResultPage(
    hint: String = L("Cadrez la couverture entière, bien éclairée et sans reflet. Ce scan n'a pas été décompté."),
    onRetake: () -> Unit,
    onDismiss: () -> Unit,
) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        EmptyState(
            "book.closed",
            L("Aucun livre reconnu"),
            hint,
            primary = EmptyStateAction(L("Reprendre une photo")) { onRetake() },
            secondary = EmptyStateAction(L("Ajouter à la main")) { onDismiss() },
        )
    }
}

/** The analysis failed: run it again on the same photo, or take another. */
@Composable
fun ScanFailedPage(reason: String?, onRetry: () -> Unit, onRetake: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            EmptyState(
                "exclamationmark.triangle",
                L("L'analyse n'a pas abouti"),
                L("L'analyse peut prendre jusqu'à une minute. Vous pouvez la relancer avec la même photo, sans dépenser de scan supplémentaire."),
                primary = EmptyStateAction(L("Relancer l'analyse")) { onRetry() },
                secondary = EmptyStateAction(L("Reprendre une photo")) { onRetake() },
            )
            if (!reason.isNullOrEmpty()) {
                Text(reason, style = Shiori.type.footnote, color = Shiori.colors.tertiaryLabel, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp))
            }
        }
    }
}

/** The title and hint over the shutter, under the camera. */
@Composable
fun CameraControls(title: String, hint: String, modifier: Modifier = Modifier, accessory: @Composable () -> Unit = {}, onShutter: () -> Unit) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(28.dp)) {
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = Shiori.type.title2.copy(fontWeight = FontWeight.SemiBold), color = Color.White)
            Text(hint, style = Shiori.type.callout, color = Color.White.copy(alpha = 0.75f), textAlign = TextAlign.Center)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(44.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) { accessory() }
            Shutter(84.dp, onShutter)
            Box(Modifier.size(52.dp))
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ScanPartsPreview() = PreviewSurface {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        ScanFailedPage("Le serveur ne répond pas.", onRetry = {}, onRetake = {})
        CameraControls("Couverture", "Cadrez la couverture entière.") {}
    }
}
