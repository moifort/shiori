package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol

enum class PreparationState { WAITING, WORKING, DONE, CONTINUING, FAILED }

/** One line of the checklist: a piece of work, how far it has got, and a figure under it. */
data class PreparationLine(val id: String, val label: String, val state: PreparationState, val detail: String? = null)

/** The todo list of the moment before the first dashboard, each line ticking off when its work is over. */
@Composable
fun PreparationChecklist(lines: List<PreparationLine>) {
    val shape = RoundedCornerShape(26.dp)
    Column(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.1f), shape).border(0.5.dp, Color.White.copy(alpha = 0.2f), shape).padding(horizontal = 18.dp, vertical = 4.dp)) {
        lines.forEachIndexed { index, line ->
            if (index > 0) ShioriDivider()
            Row(Modifier.padding(vertical = 13.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
                    when (line.state) {
                        PreparationState.WAITING -> Icon(Symbol("circle"), null, Modifier.size(22.dp), tint = Color.White.copy(alpha = 0.3f))
                        PreparationState.WORKING -> CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                        PreparationState.DONE -> Icon(Symbol("checkmark.circle.fill"), L("Terminé"), Modifier.size(22.dp), tint = Color.White)
                        PreparationState.CONTINUING -> Icon(Symbol("clock"), null, Modifier.size(20.dp), tint = Color.White)
                        PreparationState.FAILED -> Icon(Symbol("exclamationmark.circle"), L("Échec"), Modifier.size(20.dp), tint = Color.White)
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(line.label, style = Shiori.type.body.copy(fontWeight = FontWeight.SemiBold), color = Color.White, modifier = Modifier.alpha(if (line.state == PreparationState.WAITING) 0.4f else 1f))
                    val note = when (line.state) {
                        PreparationState.CONTINUING -> L("Se poursuit en arrière-plan")
                        PreparationState.FAILED -> L("Vous pourrez réessayer depuis les réglages")
                        else -> null
                    }
                    val shown = listOfNotNull(note, line.detail).joinToString(" · ")
                    if (shown.isNotEmpty()) Text(shown, style = Shiori.type.footnote, color = Color.White.copy(alpha = 0.6f))
                }
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun PreparationChecklistPreview() = PreviewSurface(dark = true) {
    PreparationChecklist(
        listOf(
            PreparationLine("profile", L("Votre profil"), PreparationState.DONE),
            PreparationLine("audible", L("Votre bibliothèque Audible"), PreparationState.CONTINUING),
            PreparationLine("goodreads", L("Votre bibliothèque Goodreads"), PreparationState.CONTINUING, "640 couvertures sur 1 424"),
            PreparationLine("home", L("Votre accueil"), PreparationState.WORKING),
        ),
    )
}
