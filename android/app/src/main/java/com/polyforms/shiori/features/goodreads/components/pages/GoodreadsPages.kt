package com.polyforms.shiori.features.goodreads.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.R
import com.polyforms.shiori.features.goodreads.GoodreadsChoices
import com.polyforms.shiori.features.goodreads.GoodreadsFileError
import com.polyforms.shiori.features.goodreads.GoodreadsFixtures
import com.polyforms.shiori.features.goodreads.GoodreadsImportOutcome
import com.polyforms.shiori.features.goodreads.GoodreadsImportSummary
import com.polyforms.shiori.features.goodreads.GoodreadsPreview
import com.polyforms.shiori.features.goodreads.GoodreadsRow
import com.polyforms.shiori.features.goodreads.GoodreadsVerdict
import com.polyforms.shiori.features.home.components.organisms.PreparationChecklist
import com.polyforms.shiori.features.home.components.organisms.PreparationLine
import com.polyforms.shiori.features.home.components.organisms.PreparationState
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.EmptyStateAction
import com.polyforms.shiori.shared.components.molecules.Figure
import com.polyforms.shiori.shared.components.molecules.FiguresLine
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.actionLabelStyle
import com.polyforms.shiori.shared.shell.CoverVeil
import com.polyforms.shiori.shared.shell.CoverWall
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

// MARK: - Shared parts

@Composable
private fun GoodreadsLogo(size: Dp, tile: Dp? = null, corner: Dp = 16.dp) {
    val logo = @Composable { Icon(painterResource(R.drawable.logo_goodreads), null, Modifier.size(size), tint = Shiori.colors.label) }
    if (tile == null) logo() else Box(Modifier.size(tile).clip(RoundedCornerShape(corner)).background(Shiori.colors.secondaryGroupedBackground), contentAlignment = Alignment.Center) { logo() }
}

/** A wide white or glass button, as the iOS `.actionWide` and `.actionGlass` draw. */
@Composable
private fun WideButton(title: String, glass: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    ActionButton(onClick, Modifier.fillMaxWidth(), fill = if (glass) ActionFill.GLASS else ActionFill.WHITE, height = 50.dp, spansWidth = true, enabled = enabled) {
        Text(title, style = actionLabelStyle(50.dp), color = if (glass) Color.White else Color.Black, maxLines = 1)
    }
}

@Composable
private fun BottomButtons(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { content() }
}

/**
 * The head of the Goodreads pages: a tilted wall of the covers the export found, sharp in the
 * middle, frosted under the status bar and under the title at its foot, as `CoverVeil` frosts
 * the cover wall on Android.
 */
@Composable
fun GoodreadsMosaic(books: List<Book>, height: Dp = 400.dp) {
    @Composable
    fun Wall(modifier: Modifier = Modifier) {
        Column(modifier.requiredWidth(720.dp).offset(x = (-20).dp, y = (-24).dp).rotate(-8f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(4) { row ->
                Row(Modifier.offset(x = if (row % 2 == 0) (-40).dp else 0.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(8) { column ->
                        if (books.isNotEmpty()) BookCover(books[(row * 5 + column) % books.size], width = 78.dp, showsFormatBadge = false)
                    }
                }
            }
        }
    }
    Box(Modifier.fillMaxWidth().height(height).background(Color.Black).clip(RoundedCornerShape(0.dp)), contentAlignment = Alignment.Center) {
        Wall()
        // The frosted veil the cover wall wears on Android (`CoverVeil`), under the status bar
        // and rising under the title at the foot, into the page's black.
        val veil = Color(0xE61C1C1E)
        Box(Modifier.matchParentSize().background(Brush.verticalGradient(0f to veil, 0.16f to Color.Transparent, 0.4f to Color.Transparent, 0.8f to veil, 1f to Color.Black)))
    }
}

@Composable
private fun SectionTitle(title: String, detail: String? = null, warns: Boolean = false, onClick: (() -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(horizontal = 20.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = Shiori.type.title2, color = if (warns) Shiori.colors.orange else Shiori.colors.label, modifier = Modifier.weight(1f))
        if (detail != null) Text(detail, style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel)
    }
}

@Composable
private fun Rail(rows: List<GoodreadsRow>, poster: @Composable (GoodreadsRow) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
        rows.take(20).forEach { poster(it) }
    }
}

@Composable
private fun Footnote(text: String) {
    Text(text, style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel, modifier = Modifier.padding(horizontal = 34.dp))
}

@Composable
private fun HeroTitle(title: String, subtitle: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)) {
        Text(title, style = Shiori.type.largeTitle.copy(fontWeight = FontWeight.ExtraBold), color = Color.White, textAlign = TextAlign.Center)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(painterResource(R.drawable.logo_goodreads), null, Modifier.size(15.dp), tint = Color.White.copy(alpha = 0.85f))
            Text(subtitle, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.85f))
        }
    }
}

// MARK: - Explain

/** How to get the Goodreads export file, and the two ways on. */
@Composable
fun GoodreadsExplainPage(onChooseFile: () -> Unit, onOpenGoodreads: () -> Unit) {
    val colors = Shiori.colors
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, start = 20.dp, end = 20.dp, bottom = 24.dp)) {
            GoodreadsLogo(34.dp, tile = 64.dp)
            Text(L("Votre bibliothèque Goodreads"), style = Shiori.type.title, color = colors.label, modifier = Modifier.padding(top = 16.dp))
            Text(L("Goodreads ne partage pas vos livres avec d'autres apps : tout passe par son fichier d'export, qui garde vos étagères, vos notes et vos dates de lecture."), style = Shiori.type.subheadline, color = colors.secondaryLabel, modifier = Modifier.padding(top = 8.dp))
            Column(Modifier.padding(top = 20.dp).fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(colors.secondaryGroupedBackground).padding(horizontal = 16.dp)) {
                listOf(
                    L("Ouvrez la page d'export") to L("Connecté à votre compte Goodreads."),
                    L("Touchez « Export Library »") to L("Le fichier se prépare, quelques minutes pour une grande bibliothèque."),
                    L("Touchez « Your export from… »") to L("Le fichier .csv arrive dans vos Téléchargements."),
                ).forEachIndexed { index, (title, detail) ->
                    if (index > 0) ShioriDivider()
                    Row(Modifier.padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(28.dp).clip(CircleShape).background(colors.tertiaryFill), contentAlignment = Alignment.Center) {
                            Text("${index + 1}", style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(title, style = Shiori.type.body, color = colors.label)
                            Text(detail, style = Shiori.type.footnote, color = colors.secondaryLabel)
                        }
                    }
                }
            }
            Text(L("Goodreads réserve cette page à l'ordinateur. Si son site mobile s'affiche, touchez ⋮ › Version pour ordinateur. Depuis Fichiers, Partager › Shiori fonctionne aussi."), style = Shiori.type.footnote, color = colors.secondaryLabel, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp))
        }
        BottomButtons {
            WideButton(L("Choisir le fichier"), onClick = onChooseFile)
            WideButton(L("Ouvrir Goodreads"), glass = true, onClick = onOpenGoodreads)
        }
    }
}

// MARK: - Reading

/** The file being read, as the checklist the onboarding ends on. */
@Composable
fun GoodreadsReadingPage(preview: GoodreadsPreview?) {
    Box(Modifier.fillMaxSize()) {
        CoverWall()
        CoverVeil(covering = true)
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box(Modifier.size(84.dp).clip(RoundedCornerShape(19.dp)).background(Color(0xFF1C1C1E)), contentAlignment = Alignment.Center) {
                Icon(painterResource(R.drawable.logo_goodreads), null, Modifier.size(44.dp), tint = Color.White)
            }
            Text(L("Préparation de votre import"), style = Shiori.type.headline, color = Color.White, modifier = Modifier.padding(top = 24.dp, bottom = 20.dp))
            PreparationChecklist(readingLines(preview))
            Text(L("L'aperçu s'ouvre dès la comparaison faite. Les couvertures se cherchent ensuite en arrière-plan."), style = Shiori.type.footnote, color = Color.White.copy(alpha = 0.6f), textAlign = TextAlign.Center, modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 16.dp))
        }
    }
}

/** The lines for a read under way, or done with what it found. */
fun readingLines(preview: GoodreadsPreview?): List<PreparationLine> {
    if (preview == null) {
        return listOf(
            PreparationLine("file", L("Lecture du fichier"), PreparationState.WORKING),
            PreparationLine("shelves", L("Vos étagères"), PreparationState.WAITING),
            PreparationLine("compare", L("Comparaison avec vos livres"), PreparationState.WAITING),
            PreparationLine("covers", L("Couvertures et séries"), PreparationState.WAITING),
        )
    }
    return listOf(
        PreparationLine("file", L("Lecture du fichier"), PreparationState.DONE, L("%lld livres", preview.rows.size)),
        PreparationLine("shelves", L("Vos étagères"), PreparationState.DONE, L("%lld lus · %lld en cours · %lld à lire · %lld abandonnés", preview.readCount, preview.readingCount, preview.toReadCount, preview.droppedCount)),
        PreparationLine("compare", L("Comparaison avec vos livres"), PreparationState.DONE),
        PreparationLine("covers", L("Couvertures et séries"), PreparationState.CONTINUING),
    )
}

// MARK: - Preview

enum class GoodreadsFilter { ALL, NEW, UNCERTAIN, HELD }

sealed interface GoodreadsPreviewAction {
    data class ShowBooks(val filter: GoodreadsFilter) : GoodreadsPreviewAction
    data class Decide(val row: GoodreadsRow) : GoodreadsPreviewAction
    data object Import : GoodreadsPreviewAction
}

private fun compact(value: Int): String = if (value < 1000) "$value" else {
    val thousands = value / 1000.0
    (if (thousands < 10) "%.1f".format(thousands).trimEnd('0').trimEnd('.', ',') else "${thousands.toInt()}") + "k"
}

/** What the export holds, set out as a book's page: the wall of covers, the figures, the rails, the boxes. */
@Composable
fun GoodreadsPreviewPage(preview: GoodreadsPreview, choices: GoodreadsChoices, isImporting: Boolean, onChoices: (GoodreadsChoices) -> Unit, onAction: (GoodreadsPreviewAction) -> Unit) {
    Column(Modifier.fillMaxSize().background(Shiori.colors.background)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            Box(contentAlignment = Alignment.BottomCenter) {
                GoodreadsMosaic(preview.rows.take(40).map { it.cover })
                HeroTitle(L("%lld livres", preview.rows.size), L("Votre export Goodreads"))
            }
            Box(Modifier.padding(top = 22.dp)) {
                FiguresLine(listOf(Figure(compact(preview.readCount), L("Lus")), Figure(compact(preview.readingCount), L("En cours")), Figure(compact(preview.toReadCount), L("À lire")), Figure(compact(preview.ratedCount), L("Notés"))))
            }
            Column(Modifier.padding(top = 30.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SectionTitle(L("Nouveaux"), "${preview.newRows.size} ›") { onAction(GoodreadsPreviewAction.ShowBooks(GoodreadsFilter.NEW)) }
                    Rail(preview.newRows) { PosterCover(it.cover, it.caption(choices.toRead)) }
                }
                if (preview.uncertainRows.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        SectionTitle(L("À vérifier"), "${preview.uncertainRows.size} ›", warns = true) { onAction(GoodreadsPreviewAction.ShowBooks(GoodreadsFilter.UNCERTAIN)) }
                        Rail(preview.uncertainRows) { row ->
                            Box(Modifier.clickable { onAction(GoodreadsPreviewAction.Decide(row)) }) {
                                PosterCover(row.heldCover ?: row.cover, uncertainCaption(row, choices))
                            }
                        }
                    }
                }
                if (preview.heldRows.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        SectionTitle(L("Déjà chez vous"), "${preview.heldRows.size} ›") { onAction(GoodreadsPreviewAction.ShowBooks(GoodreadsFilter.HELD)) }
                        Rail(preview.heldRows) { PosterCover(it.heldCover ?: it.cover, L("Complété")) }
                        Footnote(L("Ils prennent la note et la date de Goodreads quand ils n'en ont pas. Un livre papier et sa version Kindle restent un seul livre."))
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionTitle(L("Étagères"))
                    FormSection(footer = L("« À lire » est souvent une liste d'envies sur Goodreads. Si vous possédez ces livres, choisissez Pile à lire.")) {
                        ShelfRow(L("Lus"), preview.readCount, L("Lu"))
                        ShelfRow(L("En cours"), preview.readingCount, L("En cours"))
                        MenuPicker(
                            selection = choices.toRead,
                            options = GoodreadsChoices.ToRead.entries,
                            label = { if (it == GoodreadsChoices.ToRead.WISHLIST) L("Envies") else L("Pile à lire") },
                            onSelect = { onChoices(choices.copy(toRead = it)) },
                            divider = preview.droppedCount > 0,
                        ) { ShelfLabel(L("À lire"), preview.toReadCount) }
                        if (preview.droppedCount > 0) ShelfRow(L("Abandonnés"), preview.droppedCount, L("Abandonné"), divider = false)
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionTitle(L("Repris de Goodreads"))
                    FormSection {
                        ToggleRow(L("Notes"), L("%lld livres notés", preview.ratedCount), choices.keepRatings) { onChoices(choices.copy(keepRatings = it)) }
                        ToggleRow(L("Dates de lecture"), L("%lld livres datés", preview.datedCount), choices.keepDates) { onChoices(choices.copy(keepDates = it)) }
                        ToggleRow(L("Critiques"), L("%lld critiques, dans la note du livre", preview.reviewedCount), choices.keepReviews, divider = false) { onChoices(choices.copy(keepReviews = it)) }
                    }
                }
            }
        }
        BottomButtons {
            val count = choices.importedCount(preview)
            WideButton(if (count == 0) L("Compléter vos livres") else L("Importer %lld livres", count), enabled = !isImporting && choices.keys.isNotEmpty()) { onAction(GoodreadsPreviewAction.Import) }
        }
    }
}

private fun uncertainCaption(row: GoodreadsRow, choices: GoodreadsChoices): String = when {
    row.key in choices.sameBooks -> L("Même livre")
    row.key in choices.keys -> L("Deux livres")
    else -> L("Déjà chez vous ?")
}

@Composable
private fun ShelfLabel(title: String, count: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, style = Shiori.type.body, color = Shiori.colors.label)
        Text(L("%lld livres", count), style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel)
    }
}

@Composable
private fun ShelfRow(title: String, count: Int, target: String, divider: Boolean = true) {
    FormRow(divider = divider) {
        Box(Modifier.weight(1f)) { ShelfLabel(title, count) }
        Text(target, style = Shiori.type.body, color = Shiori.colors.secondaryLabel)
    }
}

@Composable
private fun ToggleRow(title: String, detail: String, checked: Boolean, divider: Boolean = true, onChange: (Boolean) -> Unit) {
    FormRow(divider = divider) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Shiori.type.body, color = Shiori.colors.label)
            Text(detail, style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel)
        }
        ShioriSwitch(checked, onChange)
    }
}

// MARK: - Books

/** Every book of the export, to tick through; a held book stays in the list, untappable. */
@Composable
fun GoodreadsBooksPage(preview: GoodreadsPreview, choices: GoodreadsChoices, filter: GoodreadsFilter, onFilter: (GoodreadsFilter) -> Unit, onChoices: (GoodreadsChoices) -> Unit, onDecide: (GoodreadsRow) -> Unit) {
    val colors = Shiori.colors
    val rows = when (filter) {
        GoodreadsFilter.ALL -> preview.rows
        GoodreadsFilter.NEW -> preview.newRows
        GoodreadsFilter.UNCERTAIN -> preview.uncertainRows
        GoodreadsFilter.HELD -> preview.heldRows
    }
    Column(Modifier.fillMaxSize().background(colors.background).statusBarsPadding().padding(top = 56.dp)) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().clip(CircleShape).background(colors.tertiaryFill).padding(2.dp)) {
            listOf(GoodreadsFilter.ALL to L("Tous"), GoodreadsFilter.UNCERTAIN to L("À vérifier · %lld", preview.uncertainRows.size), GoodreadsFilter.HELD to L("Déjà chez vous")).forEach { (value, title) ->
                val selected = filter == value || (value == GoodreadsFilter.ALL && filter == GoodreadsFilter.NEW)
                Box(Modifier.weight(1f).clip(CircleShape).background(if (selected) colors.secondaryGroupedBackground else Color.Transparent).clickable { onFilter(value) }.padding(vertical = 6.dp), contentAlignment = Alignment.Center) {
                    Text(title, style = Shiori.type.footnote.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium), color = colors.label, maxLines = 1)
                }
            }
        }
        LazyColumn(Modifier.fillMaxSize()) {
            items(rows, key = { it.key }) { row ->
                val ticked = row.key in choices.keys
                Row(
                    Modifier.fillMaxWidth().alpha(if (row.verdict == GoodreadsVerdict.HELD) 0.55f else 1f).clickable(enabled = row.verdict != GoodreadsVerdict.HELD) {
                        when {
                            row.verdict == GoodreadsVerdict.UNCERTAIN -> onDecide(row)
                            ticked -> onChoices(choices.copy(keys = choices.keys - row.key))
                            else -> onChoices(choices.copy(keys = choices.keys + row.key))
                        }
                    }.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Symbol(if (row.verdict != GoodreadsVerdict.HELD && ticked) "checkmark.circle.fill" else "circle"), null, Modifier.size(24.dp), tint = colors.label)
                    BookCover(row.heldCover ?: row.cover, width = 32.dp, showsFormatBadge = false)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        if (row.verdict == GoodreadsVerdict.UNCERTAIN && !ticked) {
                            Text(L("Peut-être déjà chez vous"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium), color = colors.orange)
                            Text("${row.heldTitle ?: row.title} · ${row.authors.firstOrNull().orEmpty()}", style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = 1)
                        } else {
                            Text(row.title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 1)
                            val author = row.authors.firstOrNull().orEmpty()
                            Text(row.volume?.let { "$author · ${L("Tome %lld", it)}" } ?: author, style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = 1)
                        }
                    }
                    Text(
                        if (row.verdict == GoodreadsVerdict.HELD) L("Déjà chez vous") else row.caption(choices.toRead),
                        style = Shiori.type.caption,
                        color = colors.secondaryLabel,
                        modifier = Modifier.clip(CircleShape).background(colors.tertiaryFill).padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
                ShioriDivider()
            }
        }
    }
}

// MARK: - Same book?

/** An uncertain row beside the book the library holds, for the reader to say whether they are one. */
@Composable
fun GoodreadsSameBookSheetContent(row: GoodreadsRow, onSame: () -> Unit, onDifferent: () -> Unit) {
    val colors = Shiori.colors
    Column(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text(L("Est-ce le même livre ?"), style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.padding(top = 8.dp))
        Row(Modifier.padding(horizontal = 24.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            listOf(Triple(L("Dans Shiori"), row.heldCover ?: row.cover, row.heldTitle ?: row.title), Triple(L("Sur Goodreads"), row.cover, row.title)).forEach { (label, book, title) ->
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(label, style = Shiori.type.footnote, color = colors.secondaryLabel)
                    BookCover(book, width = 96.dp, showsFormatBadge = false)
                    Text(title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label, textAlign = TextAlign.Center)
                    Text(book.authors.firstOrNull().orEmpty(), style = Shiori.type.footnote, color = colors.secondaryLabel)
                }
            }
        }
        Text(L("Le même : votre livre prend la note et la date de Goodreads."), style = Shiori.type.footnote, color = colors.secondaryLabel, textAlign = TextAlign.Center)
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            WideButton(L("Même livre"), onClick = onSame)
            WideButton(L("Deux livres différents"), glass = true, onClick = onDifferent)
        }
    }
}

// MARK: - Progress and result

/** An import under way, from the settings. */
@Composable
fun GoodreadsProgressPage(covers: List<Book>, done: Int, total: Int, progress: Float) {
    Column(Modifier.fillMaxSize().background(Shiori.colors.background).padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Row(horizontalArrangement = Arrangement.spacedBy((-22).dp)) {
            covers.take(5).forEachIndexed { index, book -> BookCover(book, width = 70.dp, showsFormatBadge = false, modifier = Modifier.rotate((index - 2) * 6f)) }
        }
        Text(L("%lld sur %lld", done, total), style = Shiori.type.largeTitle, color = Shiori.colors.label, modifier = Modifier.padding(top = 36.dp))
        LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth().padding(top = 16.dp), color = Color.White, trackColor = Shiori.colors.tertiaryFill)
        Text(L("Vos livres arrivent dans la bibliothèque au fil de l'import. Vous pouvez fermer cet écran : l'import continue."), style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 16.dp))
    }
}

/** How an import ended, set out as the preview was. */
@Composable
fun GoodreadsDonePage(outcome: GoodreadsImportOutcome, preview: GoodreadsPreview, choices: GoodreadsChoices, onShowLibrary: () -> Unit) {
    val added = preview.rows.filter { it.key in choices.keys && it.verdict != GoodreadsVerdict.HELD && it.key !in choices.sameBooks }
    fun count(status: ReadingStatus) = added.count { it.status(choices.toRead) == status }
    Column(Modifier.fillMaxSize().background(Shiori.colors.background)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            Box(contentAlignment = Alignment.BottomCenter) {
                GoodreadsMosaic(added.take(40).map { it.cover })
                HeroTitle(L("%lld livres importés", outcome.imported), L("Depuis Goodreads"))
            }
            Box(Modifier.padding(top = 22.dp)) {
                FiguresLine(listOf(Figure(compact(count(ReadingStatus.READ)), L("Lus")), Figure(compact(count(ReadingStatus.READING)), L("En cours")), Figure(compact(outcome.wished), L("Envies")), Figure(compact(count(ReadingStatus.DROPPED)), L("Abandonnés"))))
            }
            Column(Modifier.padding(top = 30.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SectionTitle(L("Ajoutés"), "${outcome.imported}")
                    Rail(added) { PosterCover(it.cover, it.caption(choices.toRead)) }
                }
                if (outcome.completed > 0) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        SectionTitle(L("Déjà chez vous"), "${outcome.completed}")
                        Rail(preview.heldRows) { PosterCover(it.heldCover ?: it.cover, L("Complété")) }
                    }
                }
            }
        }
        BottomButtons { WideButton(L("Voir ma bibliothèque"), onClick = onShowLibrary) }
    }
}

// MARK: - Settings and failures

/** Goodreads in the settings: the last import, a new one, and how to export. */
@Composable
fun GoodreadsSourcePage(summary: GoodreadsImportSummary?, isLoading: Boolean, onImport: () -> Unit, onHowTo: () -> Unit) {
    val colors = Shiori.colors
    Column(Modifier.fillMaxSize().background(colors.groupedBackground).verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        if (summary != null) {
            FormSection(L("Dernier import")) {
                InfoRow(L("Importé le"), summary.importedAt?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)) ?: "—")
                InfoRow(L("Livres importés"), "${summary.imported}")
                InfoRow(L("Déjà chez vous, complétés"), "${summary.completed}", divider = summary.withoutCover > 0)
                if (summary.withoutCover > 0) InfoRow(L("Sans couverture"), "${summary.withoutCover}", divider = false)
            }
            FormSection(footer = L("Un export plus récent ajoute vos nouveaux livres et met à jour statuts, notes et dates, sans créer de doublon.")) {
                FormRow(divider = false, onClick = onImport) { Text(L("Importer un nouvel export"), style = Shiori.type.body, color = colors.accent) }
            }
        } else if (isLoading) {
            FormSection { FormRow(divider = false) { Text(L("Lecture du dernier import…"), style = Shiori.type.body, color = colors.secondaryLabel) } }
        } else {
            FormSection(footer = L("Vos étagères, vos notes et vos dates de lecture arrivent depuis le fichier d'export de Goodreads.")) {
                FormRow(divider = false, onClick = onImport) { Text(L("Importer ma bibliothèque"), style = Shiori.type.body, color = colors.accent) }
            }
        }
        FormSection {
            FormRow(divider = false, onClick = onHowTo) {
                Text(L("Comment exporter depuis Goodreads"), style = Shiori.type.body, color = colors.label, modifier = Modifier.weight(1f))
                Icon(Symbol("chevron.right"), null, Modifier.size(14.dp), tint = colors.secondaryLabel)
            }
        }
    }
}

@Composable
private fun InfoRow(title: String, value: String, divider: Boolean = true) {
    FormRow(divider = divider) {
        Text(title, style = Shiori.type.body, color = Shiori.colors.label, modifier = Modifier.weight(1f))
        Text(value, style = Shiori.type.body, color = Shiori.colors.secondaryLabel)
    }
}

/** A file that could not be imported: not Goodreads', empty, or unreadable. */
@Composable
fun GoodreadsFailurePage(kind: GoodreadsFileError.Kind?, message: String?, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize().background(Shiori.colors.background), contentAlignment = Alignment.Center) {
        val retry = EmptyStateAction(L("Choisir un autre fichier")) { onRetry() }
        when (kind) {
            GoodreadsFileError.Kind.NOT_GOODREADS -> EmptyState("doc.questionmark", L("Ce fichier ne vient pas de Goodreads"), L("Choisissez le fichier goodreads_library_export.csv préparé par Goodreads."), primary = retry)
            GoodreadsFileError.Kind.EMPTY -> EmptyState("book", L("Aucun livre dans ce fichier"), L("Vérifiez que vous étiez connecté au bon compte Goodreads au moment de l'export."), primary = retry)
            else -> EmptyState("exclamationmark.triangle", L("Import impossible"), message ?: L("Le fichier n'a pas pu être lu."), primary = retry)
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun GoodreadsPagesPreview() = PreviewSurface(dark = true) {
    GoodreadsPreviewPage(GoodreadsFixtures.preview, GoodreadsChoices.of(GoodreadsFixtures.preview), isImporting = false, onChoices = {}, onAction = {})
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun GoodreadsSourcePagePreview() = PreviewSurface(dark = true) {
    GoodreadsSourcePage(GoodreadsFixtures.summary, isLoading = false, onImport = {}, onHowTo = {})
}

