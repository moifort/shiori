package com.polyforms.shiori.features.goodreads

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsBooksPage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsDonePage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsExplainPage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsFailurePage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsFilter
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsPreviewAction
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsPreviewPage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsProgressPage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsReadingPage
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsSameBookSheetContent
import com.polyforms.shiori.features.goodreads.components.pages.GoodreadsSourcePage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class GoodreadsImportMode { SETTINGS, ONBOARDING }

private sealed interface Step {
    data object Explain : Step
    data object Reading : Step
    data object Preview : Step
    data class Failed(val kind: GoodreadsFileError.Kind?, val message: String?) : Step
    data object Importing : Step
}

/**
 * The Goodreads import, connected: how to export, the file picked, read and compared, the
 * reader's choices, then the import. From the settings it ends on the progress and the result;
 * from the onboarding it hands the import to the background and the checklist takes over.
 */
@Composable
fun GoodreadsImportScreen(mode: GoodreadsImportMode = GoodreadsImportMode.SETTINGS, file: Uri? = null, onFinished: (started: Boolean) -> Unit) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    val navigator = currentNavigator
    val importer = GoodreadsBackgroundImport
    var step by remember { mutableStateOf<Step>(Step.Explain) }
    var csv by remember { mutableStateOf<String?>(null) }
    var preview by remember { mutableStateOf<GoodreadsPreview?>(null) }
    var choices by remember { mutableStateOf(GoodreadsChoices(emptySet())) }
    var deciding by remember { mutableStateOf<GoodreadsRow?>(null) }

    fun read(uri: Uri) {
        step = Step.Reading
        preview = null
        scope.launch {
            val text = withContext(Dispatchers.IO) {
                runCatching { context.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) } }.getOrNull()
            }
            if (text == null) {
                step = Step.Failed(GoodreadsFileError.Kind.UNREADABLE, null)
                return@launch
            }
            csv = text
            try {
                val found = GoodreadsApi.preview(text)
                preview = found
                choices = GoodreadsChoices.of(found)
                // Long enough to read each tick.
                delay(900)
                step = Step.Preview
            } catch (error: GoodreadsFileError) {
                step = Step.Failed(error.kind, null)
            } catch (error: Exception) {
                step = Step.Failed(null, reportError(error))
            }
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if (uri != null) read(uri) }
    val pick = { picker.launch(arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/octet-stream")) }
    LaunchedEffect(file) { if (file != null && csv == null) read(file) }

    Box(Modifier.fillMaxSize().background(Shiori.colors.background)) {
        when (val current = step) {
            Step.Explain -> GoodreadsExplainPage(onChooseFile = pick, onOpenGoodreads = { uriHandler.openUri(GOODREADS_EXPORT_URL) })
            Step.Reading -> GoodreadsReadingPage(preview)
            Step.Preview -> preview?.let { found ->
                GoodreadsPreviewPage(found, choices, importer.isRunning, onChoices = { choices = it }) { action ->
                    when (action) {
                        is GoodreadsPreviewAction.ShowBooks -> navigator.push {
                            var filter by remember { mutableStateOf(action.filter) }
                            Box(Modifier.fillMaxSize()) {
                                GoodreadsBooksPage(found, choices, filter, onFilter = { filter = it }, onChoices = { choices = it }) { deciding = it }
                                ScreenBar(title = L("Livres"))
                            }
                        }
                        is GoodreadsPreviewAction.Decide -> deciding = action.row
                        GoodreadsPreviewAction.Import -> csv?.let { text ->
                            importer.start(text, choices)
                            if (mode == GoodreadsImportMode.ONBOARDING) onFinished(true) else step = Step.Importing
                        }
                    }
                }
            }
            is Step.Failed -> GoodreadsFailurePage(current.kind, current.message, onRetry = pick)
            Step.Importing -> {
                val found = preview
                val outcome = importer.outcome
                val phase = importer.phase
                when {
                    found != null && phase == GoodreadsBackgroundImport.Phase.Finished && outcome != null ->
                        GoodreadsDonePage(outcome, found, choices) {
                            importer.reset()
                            onFinished(true)
                        }
                    phase is GoodreadsBackgroundImport.Phase.Failed -> GoodreadsFailurePage(null, phase.message, onRetry = pick)
                    else -> {
                        val total = choices.importedCount(found ?: GoodreadsFixtures.preview)
                        GoodreadsProgressPage(found?.newRows.orEmpty().take(5).map { it.cover }, if (outcome == null) 0 else (total * importer.progress).toInt(), total, importer.progress)
                    }
                }
            }
        }
        if (step != Step.Reading) {
            ScreenBar(title = if (step == Step.Importing) L("Import Goodreads") else if (step == Step.Preview) null else L("Goodreads"), onBack = null, onClose = { onFinished(step == Step.Importing) })
        }
    }

    deciding?.let { row ->
        ShioriSheet(onDismiss = { deciding = null }) { dismiss ->
            GoodreadsSameBookSheetContent(
                row,
                onSame = {
                    choices = choices.copy(keys = choices.keys + row.key, sameBooks = choices.sameBooks + row.key)
                    dismiss()
                },
                onDifferent = {
                    choices = choices.copy(keys = choices.keys + row.key, sameBooks = choices.sameBooks - row.key)
                    dismiss()
                },
            )
        }
    }
}

/** Goodreads in the settings, connected: the last import, and the import itself. */
@Composable
fun GoodreadsSourceScreen(onClose: () -> Unit) {
    var summary by remember { mutableStateOf<GoodreadsImportSummary?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var importing by remember { mutableStateOf(false) }
    var reloads by remember { mutableStateOf(0) }
    LaunchedEffect(reloads) {
        summary = runCatching { GoodreadsApi.lastImport() }.onFailure { reportError(it) }.getOrNull()
        isLoading = false
    }
    if (importing) {
        GoodreadsImportScreen(GoodreadsImportMode.SETTINGS) {
            importing = false
            reloads += 1
        }
        return
    }
    Box(Modifier.fillMaxSize()) {
        GoodreadsSourcePage(summary, isLoading, onImport = { importing = true }, onHowTo = { importing = true })
        ScreenBar(title = "Goodreads", onBack = onClose)
    }
}
