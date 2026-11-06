package com.polyforms.shiori

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.polyforms.shiori.shared.PushRegistrar
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.components.styles.ShioriTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // The captures draw the App Store fixtures alone, without a session.
        if (BuildConfig.DEBUG && intent.getBooleanExtra("showcase", false)) Showcase.isOn = true
        val preview = if (BuildConfig.DEBUG) intent.getStringExtra("preview") else null
        if (intent.getBooleanExtra(OPEN_DISCOVER, false)) PushRegistrar.openDiscover.tryEmit(Unit)
        setContent {
            ShioriTheme {
                if (preview != null) DebugPreviews(preview) else ShioriRoot()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(OPEN_DISCOVER, false)) PushRegistrar.openDiscover.tryEmit(Unit)
    }

    companion object {
        const val OPEN_DISCOVER = "openDiscover"
    }
}
