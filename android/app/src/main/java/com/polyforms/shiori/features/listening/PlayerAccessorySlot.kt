package com.polyforms.shiori.features.listening

import androidx.compose.runtime.Composable

/**
 * The title playing, floating over the tab bar as Music's capsule does, and sliding between the
 * chosen tab and the scanner once the bar is folded. Null while nothing plays.
 *
 * Placeholder of the Android catch-up's foundation: the Audible player is not ported (its
 * FairPlay stream has no Android counterpart yet), so nothing ever plays. The Listening lot
 * fills this in, keeping the signature.
 */
@Composable
fun playerAccessory(): (@Composable () -> Unit)? = null
