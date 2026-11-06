package com.polyforms.shiori.shared.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.R
import kotlinx.coroutines.delay

private val LaunchBackground = Color.Black

/** The launch: the app's icon rising over the drifting covers. */
@Composable
fun LaunchCurtain() {
    val covers = rememberLaunchCovers()
    val icon = remember { Animatable(0f) }
    LaunchedEffect(Unit) { icon.animateTo(1f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow)) }
    Box(Modifier.fillMaxSize().background(LaunchBackground), contentAlignment = Alignment.Center) {
        CoverDrift(covers)
        Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(LaunchBackground.copy(alpha = 0.7f), LaunchBackground.copy(alpha = 0.4f), Color.Transparent), radius = 600f)))
        Image(
            painterResource(R.drawable.launch_icon),
            "Shiori",
            Modifier
                .size(140.dp)
                .scale(0.8f + 0.2f * icon.value)
                .alpha(icon.value.coerceIn(0f, 1f))
                .shadow(16.dp, RoundedCornerShape(31.dp))
                .clip(RoundedCornerShape(31.dp)),
        )
    }
}

/** The curtain over the app until it is ready, shown at least two seconds, then faded. */
@Composable
fun LaunchCurtainHost(ready: Boolean, content: @Composable () -> Unit) {
    var entranceOver by remember { mutableStateOf(false) }
    var gone by remember { mutableStateOf(false) }
    val fade = remember { Animatable(1f) }
    LaunchedEffect(Unit) {
        delay(2000)
        entranceOver = true
    }
    LaunchedEffect(ready && entranceOver) {
        if (ready && entranceOver && !gone) {
            fade.animateTo(0f, tween(700))
            gone = true
        }
    }
    Box(Modifier.fillMaxSize()) {
        content()
        if (!gone) Box(Modifier.fillMaxSize().alpha(fade.value)) { LaunchCurtain() }
    }
}
