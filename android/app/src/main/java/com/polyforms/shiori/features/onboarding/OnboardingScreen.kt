package com.polyforms.shiori.features.onboarding

import androidx.compose.runtime.Composable
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.platform.LoadingScreen

@Composable
fun OnboardingScreen(onCompleted: (String, AccountAvatar) -> Unit) = LoadingScreen()
