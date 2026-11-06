package com.polyforms.shiori.shared

/**
 * The App Store fixtures, drawn without a session: debug builds launched with the `showcase`
 * extra open on them, so every screen can be captured without signing in.
 */
object Showcase {
    @Volatile var isOn: Boolean = false
}
