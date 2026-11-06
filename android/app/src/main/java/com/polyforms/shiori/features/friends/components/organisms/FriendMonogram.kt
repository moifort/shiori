package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val palettes = listOf(
    Color(0.36f, 0.85f, 0.45f) to Color(0.07f, 0.55f, 0.24f),
    Color(0.40f, 0.72f, 1f) to Color(0.10f, 0.36f, 0.86f),
    Color(1f, 0.62f, 0.32f) to Color(0.90f, 0.32f, 0.10f),
    Color(0.86f, 0.52f, 1f) to Color(0.52f, 0.22f, 0.86f),
    Color(1f, 0.48f, 0.62f) to Color(0.86f, 0.16f, 0.38f),
    Color(0.32f, 0.86f, 0.86f) to Color(0.05f, 0.52f, 0.62f),
)

/** A person's initials on a gradient picked from their name. */
@Composable
fun FriendMonogram(name: String, size: Dp = 44.dp, modifier: Modifier = Modifier) {
    val (top, bottom) = palettes[name.sumOf { it.code } % palettes.size]
    val initials = name.split(" ").filter { it.isNotEmpty() }.take(2).map { it.first() }.joinToString("").uppercase()
    Box(
        modifier.size(size).background(Brush.linearGradient(listOf(top, bottom)), CircleShape).border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(initials, style = TextStyle(fontSize = (size.value * 0.4f).sp, fontWeight = FontWeight.SemiBold), color = Color.White)
    }
}
