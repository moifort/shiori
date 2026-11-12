package com.polyforms.shiori.features.book.components.pages

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.LMarkdown
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** "Où en êtes-vous ?": a big page figure typed on a keypad, the bar, and Lu / Abandonné. */
@Composable
fun ReadingProgressSheet(
    current: Int?,
    pageCount: Int?,
    onDismiss: () -> Unit,
    onSave: suspend (page: Int?, status: ReadingStatus?) -> String?,
) {
    var digits by remember { mutableStateOf(current?.toString() ?: "") }
    var pristine by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    val typed = digits.toIntOrNull()
    val edited = typed?.takeIf { it > 0 && it != current }

    fun type(digit: Int) {
        val next = (if (pristine) "" else digits) + digit
        val trimmed = (next.toIntOrNull() ?: 0).toString()
        if (trimmed.length > 5) return
        if (pageCount != null && (trimmed.toIntOrNull() ?: 0) > pageCount) return
        pristine = false
        digits = if (trimmed == "0") "" else trimmed
        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
    }

    ShioriSheet(onDismiss) { dismiss ->
        suspend fun save(then: ReadingStatus?) {
            saving = true
            val failure = onSave(edited, then)
            saving = false
            if (failure != null) error = failure else dismiss()
        }
        SheetBar(
            L("Où en êtes-vous ?"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = { AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = edited != null && !saving) { save(null) } },
        )
        Column(Modifier.fillMaxWidth().navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                var caret by remember { mutableStateOf(true) }
                LaunchedEffect(Unit) {
                    while (true) {
                        delay(530)
                        caret = !caret
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        digits.ifEmpty { "0" },
                        style = Shiori.type.largeTitle.copy(fontSize = 76.sp, lineHeight = 80.sp, fontWeight = FontWeight.Black, letterSpacing = (-2.5).sp),
                        color = if (digits.isEmpty()) colors.tertiaryLabel else colors.label,
                    )
                    Box(Modifier.size(3.dp, 62.dp).alpha(if (caret) 1f else 0f).background(colors.label, RoundedCornerShape(2.dp)))
                }
                if (pageCount != null) Text(LMarkdown("sur **%lld** pages", pageCount), style = Shiori.type.subheadline, color = colors.secondaryLabel)
            }
            if (pageCount != null) {
                val shown = minOf(typed ?: 0, pageCount)
                val fraction by animateFloatAsState(shown.toFloat() / pageCount, label = "progress")
                Column(Modifier.fillMaxWidth().padding(horizontal = 28.dp).padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(colors.quaternaryLabel)) {
                        Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(colors.label, CircleShape))
                    }
                    Row {
                        Text("${shown * 100 / pageCount}%", style = Shiori.type.caption, color = colors.secondaryLabel)
                        Spacer(Modifier.weight(1f))
                        Text(L("%lld restantes", pageCount - shown), style = Shiori.type.caption, color = colors.secondaryLabel)
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(ReadingStatus.READ to L("Lu"), ReadingStatus.DROPPED to L("Abandonné")).forEach { (status, label) ->
                    Row(
                        Modifier.weight(1f).height(50.dp).clip(CircleShape).glass(CircleShape).plainClickable { scope.launch { save(status) } },
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Symbol(status.symbol), null, Modifier.size(18.dp), tint = colors.label)
                        Text(label, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            val keys = listOf("1" to null, "2" to "ABC", "3" to "DEF", "4" to "GHI", "5" to "JKL", "6" to "MNO", "7" to "PQRS", "8" to "TUV", "9" to "WXYZ", "" to null, "0" to null, "⌫" to null)
            Column(
                Modifier.fillMaxWidth().background(colors.tertiaryFill).padding(start = 6.dp, end = 6.dp, top = 8.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(7.dp),
            ) {
                keys.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                        row.forEach { (key, letters) ->
                            when (key) {
                                "" -> Spacer(Modifier.weight(1f).heightIn(min = 46.dp))
                                "⌫" -> Box(
                                    Modifier.weight(1f).heightIn(min = 46.dp).plainClickable {
                                        pristine = false
                                        digits = digits.dropLast(1)
                                    },
                                    contentAlignment = Alignment.Center,
                                ) { Icon(Symbol("delete.left"), L("Effacer"), Modifier.size(22.dp), tint = colors.label) }
                                else -> Column(
                                    Modifier.weight(1f).heightIn(min = 46.dp).clip(RoundedCornerShape(8.dp)).background(colors.secondaryGroupedBackground)
                                        .plainClickable { type(key.toInt()) },
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center,
                                ) {
                                    Text(key, style = Shiori.type.title2.copy(fontSize = 25.sp, fontWeight = FontWeight.Normal), color = colors.label)
                                    if (letters != null) Text(letters, style = Shiori.type.caption2.copy(fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp), color = colors.label)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}

@Preview(showBackground = true)
@Composable
private fun ReadingProgressSheetPreview() = PreviewSurface {
    ReadingProgressSheet(current = 214, pageCount = 662, onDismiss = {}) { _, _ -> null }
}
