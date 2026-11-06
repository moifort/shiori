package com.polyforms.shiori

import androidx.compose.runtime.Composable
import com.polyforms.shiori.features.auth.AuthRoot

/** The app: the update gate, the sign-in, the onboarding, then the tabs. */
@Composable
fun ShioriRoot() = AuthRoot()
