package com.polyforms.shiori.features.scan

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.subscription.components.pages.PremiumSheet
import com.polyforms.shiori.features.subscription.components.pages.PremiumTrigger
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.organisms.AIGlassDrops
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.CameraView
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.scaledJpeg
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.track
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext

/** Where a book of the shelf stands once the reader asked to add it. */
sealed interface ShelfAddProgress {
    data object Waiting : ShelfAddProgress
    data object Adding : ShelfAddProgress
    data object Added : ShelfAddProgress
    data class Failed(val reason: String) : ShelfAddProgress
}

/**
 * Several books from one photo: the shelf is read, every book listed with a tick, the ones the
 * reader does not hold ticked, then added three at a time — each one a scan of the allowance.
 */
class ShelfImportViewModel(private val client: ScanClient, private val scope: CoroutineScope) {
    enum class Step { CAMERA, DETECTING, CHECKLIST, NO_RESULT, FAILED, ADDING }

    var step by mutableStateOf(Step.CAMERA)
        private set
    var photo by mutableStateOf<Bitmap?>(null)
        private set
    var books by mutableStateOf<List<DetectedBook>>(emptyList())
        private set
    var ticked by mutableStateOf<Set<Int>>(emptySet())
        private set
    var progress by mutableStateOf<Map<Int, ShelfAddProgress>>(emptyMap())
        private set
    var remainingScans by mutableStateOf<Int?>(null)
        private set
    var failure by mutableStateOf<String?>(null)
        private set
    var paywallShown by mutableStateOf(false)
    private var jpeg: ByteArray? = null
    private val crops = mutableMapOf<Int, ImageBitmap?>()

    val isDone: Boolean get() = progress.isNotEmpty() && progress.values.all { it == ShelfAddProgress.Added }

    suspend fun detect(jpeg: ByteArray) {
        this.jpeg = jpeg
        photo = withContext(Dispatchers.Default) { BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) }
        crops.clear()
        failure = null
        step = Step.DETECTING
        try {
            val remaining = scope.async { client.remainingScans() }
            books = client.detectShelf(jpeg)
            remainingScans = remaining.await()
            track(AnalyticsEvent.ShelfDetected(books.size))
            ticked = books.filter { !it.owned && it.isNamed }.map { it.id }.toSet()
            step = if (books.isEmpty()) Step.NO_RESULT else Step.CHECKLIST
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            val code = (error as? ApiError)?.domainCode
            if (code == "PREMIUM_REQUIRED" || code == "QUOTA_EXHAUSTED") {
                step = Step.CAMERA
                paywallShown = true
            } else {
                failure = reportError(error)
                step = Step.FAILED
            }
        }
    }

    suspend fun retry() {
        val jpeg = jpeg ?: return retake()
        detect(jpeg)
    }

    fun retake() {
        jpeg = null
        photo = null
        books = emptyList()
        ticked = emptySet()
        progress = emptyMap()
        crops.clear()
        failure = null
        step = Step.CAMERA
    }

    fun toggle(id: Int) {
        if (books.firstOrNull { it.id == id }?.isNamed != true) return
        ticked = if (id in ticked) ticked - id else ticked + id
    }

    /** A spine read wrong, or not at all, named by hand: it is then ticked. */
    fun correct(id: Int, title: String, authors: List<String>) {
        val trimmed = title.trim()
        if (trimmed.isEmpty()) return
        books = books.map { if (it.id == id) it.copy(title = trimmed, authors = authors) else it }
        ticked = ticked + id
    }

    /** The book's spine or cover, cut out of the photo. */
    fun crop(book: DetectedBook): ImageBitmap? = crops.getOrPut(book.id) {
        val photo = photo ?: return@getOrPut null
        val box = book.box
        val x = (box.x * photo.width).toInt().coerceIn(0, photo.width - 1)
        val y = (box.y * photo.height).toInt().coerceIn(0, photo.height - 1)
        val w = (box.width * photo.width).toInt().coerceIn(1, photo.width - x)
        val h = (box.height * photo.height).toInt().coerceIn(1, photo.height - y)
        runCatching { Bitmap.createBitmap(photo, x, y, w, h).asImageBitmap() }.getOrNull()
    }

    fun addTicked() {
        val chosen = books.filter { it.id in ticked }
        progress = chosen.associate { it.id to ShelfAddProgress.Waiting }
        step = Step.ADDING
        add(chosen)
    }

    fun retryAdding(id: Int) {
        val book = books.firstOrNull { it.id == id } ?: return
        progress = progress + (id to ShelfAddProgress.Waiting)
        add(listOf(book))
    }

    // Three at a time, kept going in the app's scope: the reader may close the screen.
    private fun add(chosen: List<DetectedBook>) {
        val gate = Semaphore(3)
        chosen.forEach { book ->
            com.polyforms.shiori.shared.AppScope.launch {
                gate.withPermit {
                    progress = progress + (book.id to ShelfAddProgress.Adding)
                    progress = progress + (book.id to try {
                        client.addDetected(book)
                        track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.SHELF))
                        ShelfAddProgress.Added
                    } catch (error: Throwable) {
                        if ((error as? ApiError)?.domainCode == "QUOTA_EXHAUSTED") ShelfAddProgress.Failed(L("Scans épuisés")) else ShelfAddProgress.Failed(reportError(error))
                    })
                }
            }
        }
    }
}

/** Several books from one photo: the camera, the reading, the checklist, the adding. */
@Composable
fun ShelfImportScreen(onDismiss: () -> Unit, startJpeg: ByteArray? = null, client: ScanClient = ScanClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { ShelfImportViewModel(client, scope) }
    val context = LocalContext.current
    var captureRequest by remember { mutableIntStateOf(0) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val jpeg = withContext(Dispatchers.IO) {
                context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }?.scaledJpeg(2000)
            } ?: return@launch
            viewModel.detect(jpeg)
        }
    }
    LaunchedEffect(Unit) { startJpeg?.let { viewModel.detect(it) } }
    val onCamera = viewModel.step == ShelfImportViewModel.Step.CAMERA
    Box(Modifier.fillMaxSize().background(if (onCamera) Color.Black else Shiori.colors.groupedBackground)) {
        when (viewModel.step) {
            ShelfImportViewModel.Step.CAMERA -> {
                CameraView(captureRequest, Modifier.fillMaxSize(), maxDimension = 2000) { jpeg -> scope.launch { viewModel.detect(jpeg) } }
                Column(
                    Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().padding(bottom = 48.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Text(
                        L("Tranches bien lisibles, ou couvertures posées à plat. Jusqu'à 30 livres."),
                        style = Shiori.type.footnote,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 24.dp).background(Color.Black.copy(alpha = 0.4f), CircleShape).padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        com.polyforms.shiori.features.scan.components.organisms.Shutter { captureRequest += 1 }
                        Box(
                            Modifier.align(Alignment.CenterStart).padding(start = 32.dp).size(52.dp).background(Color.Black.copy(alpha = 0.4f), CircleShape)
                                .plainClickable { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Symbol("photo.on.rectangle"), L("Choisir une photo"), Modifier.size(24.dp), tint = Color.White) }
                    }
                }
            }
            ShelfImportViewModel.Step.DETECTING -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(40.dp)) {
                    AIGlassDrops()
                    Text(L("Analyse de l'étagère"), style = Shiori.type.headline, color = Shiori.colors.label)
                }
            }
            ShelfImportViewModel.Step.CHECKLIST -> ShelfChecklistPage(viewModel)
            ShelfImportViewModel.Step.NO_RESULT -> com.polyforms.shiori.features.scan.components.organisms.ScanNoResultPage(
                L("Photographiez les tranches de face, bien éclairées, ou posez les couvertures à plat sans qu'elles se chevauchent. Rien n'a été décompté."),
                onRetake = viewModel::retake,
                onDismiss = onDismiss,
            )
            ShelfImportViewModel.Step.FAILED -> com.polyforms.shiori.features.scan.components.organisms.ScanFailedPage(viewModel.failure, onRetry = { scope.launch { viewModel.retry() } }, onRetake = viewModel::retake)
            ShelfImportViewModel.Step.ADDING -> ShelfAddingPage(viewModel, onDismiss)
        }
        Box(Modifier.statusBarsPadding().padding(16.dp)) { ToolbarIconButton(L("Fermer"), "xmark", onClick = onDismiss) }
    }
    if (viewModel.paywallShown) {
        PremiumSheet(PremiumTrigger.SHELF_IMPORT) {
            viewModel.paywallShown = false
            onDismiss()
        }
    }
}

/** Every book read off the photo, a tick each, the photo above with their boxes. */
@Composable
private fun ShelfChecklistPage(viewModel: ShelfImportViewModel) {
    val colors = Shiori.colors
    var highlighted by remember { mutableStateOf<Int?>(null) }
    var correcting by remember { mutableStateOf<DetectedBook?>(null) }
    var allowanceAlert by remember { mutableStateOf(false) }
    val ticked = viewModel.ticked
    Box(Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = PaddingValues(top = 72.dp, bottom = 140.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            item(key = "title") {
                Text(L("%lld livres trouvés", viewModel.books.size), style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.padding(horizontal = 20.dp))
            }
            viewModel.photo?.let { photo -> item(key = "photo") { ShelfPhoto(photo, viewModel.books, highlighted, Modifier.padding(horizontal = 16.dp)) } }
            item(key = "books") {
                FormSection {
                    viewModel.books.forEachIndexed { index, book ->
                        val isTicked = book.id in ticked
                        Row(
                            Modifier.fillMaxWidth().plainClickable {
                                highlighted = book.id
                                correcting = book
                            }.padding(horizontal = 16.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Symbol(if (isTicked) "checkmark.circle.fill" else "circle"),
                                if (isTicked) L("Décocher") else L("Cocher"),
                                Modifier.size(26.dp).plainClickable { viewModel.toggle(book.id) },
                                tint = if (isTicked) colors.accent else colors.secondaryLabel,
                            )
                            Box(Modifier.size(32.dp, 48.dp).clip(RoundedCornerShape(3.dp)).background(colors.tertiaryFill)) {
                                viewModel.crop(book)?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit) }
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                if (book.isNamed) {
                                    Text(book.title ?: "", style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2)
                                    val details = listOfNotNull(book.byline, book.seriesLabel)
                                    if (details.isNotEmpty()) Text(details.joinToString(" · "), style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                } else {
                                    Text(L("Tranche illisible"), style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.orange)
                                    Text(L("Touchez pour saisir le titre"), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                                }
                            }
                            if (book.owned) {
                                Text(L("Déjà chez vous"), style = Shiori.type.caption, color = colors.green, modifier = Modifier.background(colors.green.copy(alpha = 0.15f), CircleShape).padding(horizontal = 8.dp, vertical = 3.dp))
                            }
                        }
                        if (index < viewModel.books.lastIndex) ShioriDivider(Modifier.padding(start = 16.dp))
                    }
                }
            }
        }
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(colors.groupedBackground).navigationBarsPadding().padding(16.dp)) {
            ShioriButton(L("Ajouter %lld livres · %lld scans", ticked.size, ticked.size), large = true, fillWidth = true, enabled = ticked.isNotEmpty()) {
                val remaining = viewModel.remainingScans
                if (remaining != null && ticked.size > remaining) allowanceAlert = true else viewModel.addTicked()
            }
        }
    }
    correcting?.let { book -> DetectedBookSheet(book, viewModel.crop(book), { correcting = null }) { title, authors -> viewModel.correct(book.id, title, authors) } }
    if (allowanceAlert) {
        ShioriAlert(L("Pas assez de scans"), L("Il vous reste %lld scans ce mois-ci. Décochez des livres pour continuer.", viewModel.remainingScans ?: 0), onDismiss = { allowanceAlert = false })
    }
}

/** The photo with a box on every book read off it, the one being looked at in yellow. */
@Composable
private fun ShelfPhoto(photo: Bitmap, books: List<DetectedBook>, highlighted: Int?, modifier: Modifier = Modifier) {
    val image = remember(photo) { photo.asImageBitmap() }
    BoxWithConstraints(modifier.fillMaxWidth().aspectRatio(photo.width.toFloat() / photo.height).clip(RoundedCornerShape(12.dp))) {
        Image(image, null, Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
        books.forEach { book ->
            val isHighlighted = book.id == highlighted
            Box(
                Modifier.offset(maxWidth * book.box.x.toFloat(), maxHeight * book.box.y.toFloat())
                    .size(maxWidth * book.box.width.toFloat(), maxHeight * book.box.height.toFloat())
                    .border(if (isHighlighted) 3.dp else 1.5.dp, if (isHighlighted) Color.Yellow else Color.Green),
            )
        }
    }
}

/** A book's title and authors typed by hand, its spine shown above. */
@Composable
private fun DetectedBookSheet(book: DetectedBook, crop: ImageBitmap?, onDismiss: () -> Unit, onSave: (String, List<String>) -> Unit) {
    var title by remember { mutableStateOf(book.title ?: "") }
    var authors by remember { mutableStateOf(book.authors.joinToString(", ")) }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Corriger"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark", onClick = dismiss) },
            trailing = {
                ToolbarIconButton(L("Valider"), "checkmark", prominent = true, enabled = title.isNotBlank()) {
                    onSave(title.trim(), authors.split(",").map { it.trim() }.filter { it.isNotEmpty() })
                    dismiss()
                }
            },
        )
        Column(Modifier.padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            crop?.let { Image(it, null, Modifier.fillMaxWidth().size(120.dp), contentScale = ContentScale.Fit) }
            FormSection(L("Titre")) {
                PlainTextField(title, { title = it }, L("Titre du livre"), Modifier.padding(16.dp))
            }
            FormSection(L("Auteurs")) {
                PlainTextField(authors, { authors = it }, L("Séparés par des virgules"), Modifier.padding(16.dp))
            }
        }
    }
}

/** Each chosen book as it goes on the shelf: waiting, adding, added, or failed with a retry. */
@Composable
private fun ShelfAddingPage(viewModel: ShelfImportViewModel, onDone: () -> Unit) {
    val colors = Shiori.colors
    val chosen = viewModel.books.filter { viewModel.progress[it.id] != null }
    Box(Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = PaddingValues(top = 72.dp, bottom = 180.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            item(key = "title") {
                Text(L("Ajout de %lld livres", chosen.size), style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.padding(horizontal = 20.dp))
            }
            item(key = "books") {
                FormSection {
                    chosen.forEachIndexed { index, book ->
                        val progress = viewModel.progress[book.id] ?: ShelfAddProgress.Waiting
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                                when (progress) {
                                    ShelfAddProgress.Waiting -> Icon(Symbol("clock"), null, Modifier.size(20.dp), tint = colors.secondaryLabel)
                                    ShelfAddProgress.Adding -> CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                                    ShelfAddProgress.Added -> Icon(Symbol("checkmark.circle.fill"), null, Modifier.size(22.dp), tint = colors.green)
                                    is ShelfAddProgress.Failed -> Icon(Symbol("exclamationmark.circle.fill"), null, Modifier.size(22.dp), tint = colors.red)
                                }
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(book.title ?: "", style = Shiori.type.body, color = colors.label, maxLines = 2)
                                if (progress is ShelfAddProgress.Failed) Text(progress.reason, style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = 2)
                            }
                            if (progress is ShelfAddProgress.Failed) {
                                Text(L("Réessayer"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.plainClickable { viewModel.retryAdding(book.id) })
                            }
                        }
                        if (index < chosen.lastIndex) ShioriDivider(Modifier.padding(start = 52.dp))
                    }
                }
            }
        }
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(colors.groupedBackground).navigationBarsPadding().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!viewModel.isDone) {
                Text(L("Vous pouvez fermer : l'ajout continue et les livres apparaissent dans la bibliothèque."), style = Shiori.type.footnote, color = colors.secondaryLabel, textAlign = TextAlign.Center)
            }
            ShioriButton(L("Voir ma bibliothèque"), large = true, fillWidth = true) { onDone() }
        }
    }
}
