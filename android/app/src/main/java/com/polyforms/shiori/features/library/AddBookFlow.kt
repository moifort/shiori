package com.polyforms.shiori.features.library

import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.AppRouter
import com.polyforms.shiori.features.book.components.pages.ManualAddScreen
import com.polyforms.shiori.features.library.components.organisms.AddBookSheet
import com.polyforms.shiori.features.library.components.organisms.AddBookSource
import com.polyforms.shiori.features.scan.ScanClient
import com.polyforms.shiori.features.scan.ScanScreen
import com.polyforms.shiori.features.scan.ScanStart
import com.polyforms.shiori.features.scan.ShelfImportScreen
import com.polyforms.shiori.features.subscription.LocalSubscriptionStore
import com.polyforms.shiori.features.subscription.components.pages.PremiumSheet
import com.polyforms.shiori.features.subscription.components.pages.PremiumTrigger
import com.polyforms.shiori.shared.platform.FullScreenCover
import com.polyforms.shiori.shared.platform.NavigationStack
import com.polyforms.shiori.shared.platform.scaledJpeg
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private sealed interface AddFlow {
    data class Scan(val start: ScanStart) : AddFlow
    data object Shelf : AddFlow
    data object ShelfPaywall : AddFlow
    data object Manual : AddFlow
}

/** The add sheet and what it opens: the scan, the shelf import, a photo, the manual form. */
@Composable
fun AddBookFlow(router: AppRouter) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = LocalSubscriptionStore.current
    var flow by remember { mutableStateOf<AddFlow?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val jpeg = withContext(Dispatchers.IO) {
                context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }?.scaledJpeg()
            } ?: return@launch
            flow = AddFlow.Scan(ScanStart.Photo(jpeg))
        }
    }
    // A page shared from a browser or a bookshop app opens on its book; a shared photo is scanned.
    LaunchedEffect(Unit) {
        com.polyforms.shiori.MainActivity.shared.collect { intake ->
            @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
            com.polyforms.shiori.MainActivity.shared.resetReplayCache()
            when (intake) {
                is com.polyforms.shiori.SharedIntake.Link -> flow = AddFlow.Scan(ScanStart.Link(intake.url))
                is com.polyforms.shiori.SharedIntake.Image -> {
                    val jpeg = withContext(Dispatchers.IO) {
                        runCatching { context.contentResolver.openInputStream(intake.uri)?.use { BitmapFactory.decodeStream(it) }?.scaledJpeg() }.getOrNull()
                    }
                    if (jpeg != null) flow = AddFlow.Scan(ScanStart.Photo(jpeg))
                }
            }
        }
    }
    if (router.showAddSheet) {
        AddBookSheet(store.isPremium, ScanClient.live::searchTitle, onDismiss = { router.showAddSheet = false }) { source ->
            router.showAddSheet = false
            when (source) {
                AddBookSource.Camera -> flow = AddFlow.Scan(ScanStart.Camera)
                AddBookSource.Shelf -> flow = if (store.isPremium == false) AddFlow.ShelfPaywall else AddFlow.Shelf
                AddBookSource.Library -> picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                is AddBookSource.Title -> flow = AddFlow.Scan(ScanStart.Title(source.query))
                AddBookSource.Manual -> flow = AddFlow.Manual
            }
        }
    }
    when (val shown = flow) {
        is AddFlow.Scan -> FullScreenCover({ flow = null }) {
            NavigationStack {
                ScanScreen(
                    shown.start,
                    onDismiss = { flow = null },
                    onAwait = { _, _ ->
                        flow = null
                        router.showDiscover()
                    },
                    onAdded = { book ->
                        flow = null
                        router.openLibrary(LibraryRequest(focus = book.id))
                    },
                )
            }
        }
        AddFlow.Shelf -> FullScreenCover({ flow = null }) { ShelfImportScreen(onDismiss = { flow = null }) }
        AddFlow.ShelfPaywall -> PremiumSheet(PremiumTrigger.SHELF_IMPORT) { flow = null }
        AddFlow.Manual -> ManualAddScreen(onDismiss = { flow = null }) { flow = null }
        null -> Unit
    }
}
