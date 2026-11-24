package com.polyforms.shiori.features.scan

import com.polyforms.shiori.features.scan.components.organisms.CameraBarTitle
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.scan.components.organisms.ScanAnalyzingPage
import com.polyforms.shiori.features.scan.components.organisms.ScanFailedPage
import com.polyforms.shiori.features.scan.components.organisms.ScanNoResultPage
import com.polyforms.shiori.features.scan.components.organisms.ViewfinderOverlay
import com.polyforms.shiori.features.scan.components.pages.ScanReviewAction
import com.polyforms.shiori.features.scan.components.pages.ScanReviewPage
import com.polyforms.shiori.features.subscription.components.pages.PremiumSheet
import com.polyforms.shiori.features.subscription.components.pages.PremiumTrigger
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookOrigin
import com.polyforms.shiori.shared.components.molecules.Confirmation
import com.polyforms.shiori.shared.components.molecules.ConfirmationHost
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.CameraView
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** How a scan starts: on the camera, or on a photo, a title or a link already given. */
sealed interface ScanStart {
    data object Camera : ScanStart
    data class Photo(val jpeg: ByteArray) : ScanStart
    data class Title(val title: String) : ScanStart
    data class Link(val link: String) : ScanStart

    /** Where a book saved from this start came from, unless the caller knows better. */
    val origin: BookOrigin.Kind
        get() = when (this) {
            Camera, is Photo -> BookOrigin.Kind.SCAN
            is Title -> BookOrigin.Kind.SEARCH
            is Link -> BookOrigin.Kind.SHARE
        }
}

/** A cover scan, from the camera to the book added. */
@Composable
fun ScanScreen(
    start: ScanStart = ScanStart.Camera,
    onDismiss: () -> Unit,
    onAwait: (BookDraft, ReleaseFormat) -> Unit,
    onAdded: (Book) -> Unit,
    /** The book went onto the wishlist: once the scan has said so over the review, it closes. */
    onWished: () -> Unit = onDismiss,
    /** How a book saved here reached the library, when the caller knows better than the start: a share. */
    origin: BookOrigin.Kind? = null,
    client: ScanClient = ScanClient.live,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { ScanViewModel(client, origin ?: start.origin) }
    // What was just done, said over the screen whose button did it.
    var confirmation by remember { mutableStateOf<Confirmation?>(null) }
    // Says what was done over the review, where its button was, and moves on only once the word
    // has been read.
    suspend fun confirm(done: Confirmation, next: () -> Unit) {
        confirmation = done
        delay(Confirmation.HOLD_MILLIS)
        next()
    }
    val navigator = currentNavigator
    var captureRequest by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        when (start) {
            ScanStart.Camera -> Unit
            is ScanStart.Photo -> viewModel.capture(start.jpeg)
            is ScanStart.Title -> viewModel.lookUpTitle(start.title)
            is ScanStart.Link -> viewModel.lookUp(start.link)
        }
    }
    val onCamera = viewModel.step == ScanViewModel.Step.CAMERA
    Box(Modifier.fillMaxSize().background(if (onCamera) Color.Black else Shiori.colors.groupedBackground)) {
        when (viewModel.step) {
            ScanViewModel.Step.CAMERA -> {
                CameraView(captureRequest, Modifier.fillMaxSize()) { jpeg -> scope.launch { viewModel.capture(jpeg) } }
                ViewfinderOverlay(leavesRoomForShutter = true)
                // On a phone, as iOS: the shutter alone under the frame, the page's name in the bar.
                Box(Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 48.dp)) {
                    com.polyforms.shiori.features.scan.components.organisms.Shutter { captureRequest += 1 }
                }
                CameraBarTitle(L("Scanner une couverture"))
            }
            ScanViewModel.Step.ANALYZING -> ScanAnalyzingPage()
            ScanViewModel.Step.REVIEW -> viewModel.draft?.let { draft ->
                ScanReviewPage(
                    draft,
                    viewModel.ownedCopy,
                    viewModel.isSaving,
                    viewModel.awaitable,
                    viewModel::subgenres,
                    viewModel::vocabulary,
                    sagaVolumes = viewModel.sagaVolumes,
                    onClose = onDismiss,
                ) { action ->
                    when (action) {
                        is ScanReviewAction.Save -> viewModel.save(action.draft, action.series)?.let { book ->
                            confirm(Confirmation.addedToLibrary) { onAdded(book) }
                        }
                        ScanReviewAction.Retake -> viewModel.retake()
                        is ScanReviewAction.AwaitEdition -> confirm(Confirmation.awaited) { onAwait(action.draft, action.format) }
                        is ScanReviewAction.Wish -> if (viewModel.wish(action.draft)) confirm(Confirmation.addedToWishlist, onWished)
                        is ScanReviewAction.LanguageOrFormatChanged -> coroutineScope {
                            launch { viewModel.loadAwaitable(action.language, action.format) }
                            launch { viewModel.loadSagaVolumes(action.language) }
                        }
                        is ScanReviewAction.OpenOwnedCopy -> navigator.push { BookScreen(action.book.id) }
                    }
                }
            }
            ScanViewModel.Step.NO_RESULT -> ScanNoResultPage(onRetake = viewModel::retake, onDismiss = onDismiss)
            ScanViewModel.Step.FAILED -> ScanFailedPage(viewModel.failure, onRetry = { scope.launch { viewModel.retry() } }, onRetake = viewModel::retake)
        }
        if (viewModel.step != ScanViewModel.Step.REVIEW) {
            Box(Modifier.statusBarsPadding().padding(16.dp)) { ToolbarIconButton(L("Fermer"), "xmark", onClick = onDismiss) }
        }
        // Nothing is tapped while the word is said.
        if (confirmation != null) Box(Modifier.fillMaxSize().pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent().changes.forEach { it.consume() } } })
        ConfirmationHost(confirmation) { confirmation = null }
    }
    if (viewModel.paywallShown) {
        PremiumSheet(PremiumTrigger.SCAN_ALLOWANCE_SPENT) {
            viewModel.paywallShown = false
            onDismiss()
        }
    }
    viewModel.error?.let { ShioriAlert(L("Le scan a échoué"), it, onDismiss = { viewModel.error = null }) }
}
