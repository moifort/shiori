package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/** To read, reading, read: a capsule picker, the chosen one lifted on white. */
@Composable
fun ReadingStatusPicker(status: ReadingStatus, modifier: Modifier = Modifier, onSelect: ((ReadingStatus) -> Unit)?) {
    val colors = Shiori.colors
    val haptics = LocalHapticFeedback.current
    Row(modifier.fillMaxWidth().clip(CircleShape).background(colors.tertiaryFill).padding(3.dp)) {
        ReadingStatus.progression.forEach { option ->
            val on = option == status
            val ground by animateColorAsState(if (on) colors.background else Color.Transparent, label = "status")
            Row(
                Modifier.weight(1f).then(if (on) Modifier.shadow(1.dp, CircleShape) else Modifier).clip(CircleShape).background(ground)
                    .plainClickable(enabled = onSelect != null) {
                        haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                        onSelect?.invoke(option)
                    }
                    .padding(vertical = 7.dp),
                horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Symbol(option.symbol), null, Modifier.size(13.dp), tint = colors.label)
                Text(option.label, style = Shiori.type.subheadline.copy(fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal), color = colors.label, maxLines = 1)
            }
        }
    }
}
