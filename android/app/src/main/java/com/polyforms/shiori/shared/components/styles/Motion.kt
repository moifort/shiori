package com.polyforms.shiori.shared.components.styles

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import kotlin.math.PI

/**
 * SwiftUI's springs, so an animation ported from `withAnimation(.smooth)` moves as it does on
 * iOS: a spring of `duration` seconds and `bounce` is one of stiffness (2π / duration)² and
 * damping ratio 1 - bounce.
 */
object Motion {
    fun <T> spring(duration: Double, bounce: Double = 0.0, visibilityThreshold: T? = null): SpringSpec<T> {
        val frequency = 2 * PI / duration
        return spring(dampingRatio = (1 - bounce).toFloat(), stiffness = (frequency * frequency).toFloat(), visibilityThreshold = visibilityThreshold)
    }

    /** `.smooth`: half a second, no bounce. */
    fun <T> smooth(visibilityThreshold: T? = null): SpringSpec<T> = spring(0.5, 0.0, visibilityThreshold)

    /** `.snappy`: half a second, a small bounce. */
    fun <T> snappy(visibilityThreshold: T? = null): SpringSpec<T> = spring(0.5, 0.15, visibilityThreshold)

    /** `.bouncy`: half a second, a clear bounce. */
    fun <T> bouncy(visibilityThreshold: T? = null): SpringSpec<T> = spring(0.5, 0.3, visibilityThreshold)
}
