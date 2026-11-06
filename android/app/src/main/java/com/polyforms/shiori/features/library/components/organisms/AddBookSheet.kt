package com.polyforms.shiori.features.library.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.scan.TitleCandidate
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.launch

/** Where a book is added from. */
sealed interface AddBookSource {
    data object Camera : AddBookSource
    data object Shelf : AddBookSource
    data object Library : AddBookSource
    data class Title(val query: String) : AddBookSource
    data object Manual : AddBookSource
}

private sealed interface TitleSearch {
    data object Idle : TitleSearch
    data object Searching : TitleSearch
    data class Candidates(val list: List<TitleCandidate>) : TitleSearch
    data object NoMatch : TitleSearch
    data class Failed(val reason: String) : TitleSearch
}

/** The scan button's sheet: the camera, several books, a photo, a typed title, or by hand. */
@Composable
fun AddBookSheet(isPremium: Boolean?, searchTitle: suspend (String) -> List<TitleCandidate>, onDismiss: () -> Unit, onChoose: (AddBookSource) -> Unit) {
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    var title by remember { mutableStateOf("") }
    var search by remember { mutableStateOf<TitleSearch>(TitleSearch.Idle) }
    fun submit() {
        val typed = title.trim()
        if (typed.isEmpty() || search == TitleSearch.Searching) return
        search = TitleSearch.Searching
        scope.launch {
            search = try {
                val candidates = searchTitle(typed)
                when (candidates.size) {
                    0 -> TitleSearch.NoMatch
                    1 -> {
                        onChoose(AddBookSource.Title(candidates[0].lookUpQuery))
                        TitleSearch.Idle
                    }
                    else -> TitleSearch.Candidates(candidates)
                }
            } catch (failure: ApiError) {
                if (failure.domainCode == "QUOTA_EXHAUSTED") {
                    onChoose(AddBookSource.Title(typed))
                    TitleSearch.Idle
                } else {
                    TitleSearch.Failed(reportError(failure))
                }
            } catch (failure: Exception) {
                TitleSearch.Failed(reportError(failure))
            }
        }
    }
    ShioriSheet(onDismiss) { dismiss ->
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(colors.secondaryGroupedBackground).plainClickable { dismiss() }, contentAlignment = Alignment.Center) {
                    Icon(Symbol("xmark"), L("Fermer"), Modifier.size(16.dp), tint = colors.label)
                }
                Text(L("Ajouter un livre"), style = Shiori.type.title3.copy(fontWeight = FontWeight.SemiBold), color = colors.label, modifier = Modifier.weight(1f))
                Text(L("Toutes les photos"), style = Shiori.type.subheadline, color = colors.accent, modifier = Modifier.plainClickable { onChoose(AddBookSource.Library) })
            }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Tile("camera.viewfinder", L("Scanner la couverture")) { onChoose(AddBookSource.Camera) }
                Tile("books.vertical", L("Plusieurs livres"), badge = if (isPremium == false) L("Premium") else null) { onChoose(AddBookSource.Shelf) }
                Tile("photo.on.rectangle", L("Choisir une photo")) { onChoose(AddBookSource.Library) }
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(18.dp)).background(colors.secondaryGroupedBackground).padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Symbol("sparkles.rectangle.stack"), null, Modifier.size(22.dp), tint = colors.label)
                PlainTextField(title, {
                    title = it
                    if (search != TitleSearch.Searching) search = TitleSearch.Idle
                }, L("Un titre, l'IA cherche le reste"), Modifier.weight(1f), onDone = ::submit)
                when {
                    search == TitleSearch.Searching -> CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                    title.isNotBlank() -> Icon(Symbol("arrow.right.circle.fill"), L("Rechercher"), Modifier.size(28.dp).plainClickable(onClick = ::submit), tint = colors.accent)
                }
            }
            when (val state = search) {
                is TitleSearch.Candidates -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(L("Plusieurs livres correspondent"), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    Column(Modifier.clip(RoundedCornerShape(18.dp)).background(colors.secondaryGroupedBackground)) {
                        state.list.forEachIndexed { index, candidate ->
                            if (index > 0) ShioriDivider(Modifier.padding(start = 16.dp))
                            Row(Modifier.fillMaxWidth().plainClickable { onChoose(AddBookSource.Title(candidate.lookUpQuery)) }.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(candidate.title, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2)
                                    val byline = listOfNotNull(candidate.authors.ifEmpty { null }?.joinToString(", "), candidate.firstPublishedIn?.toString()).joinToString(" · ")
                                    if (byline.isNotEmpty()) Text(byline, style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
                                    candidate.seriesName?.let { series ->
                                        Text(candidate.volume?.let { "$series · ${L("Tome %lld", it)}" } ?: series, style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = 1)
                                    }
                                }
                                Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
                            }
                        }
                    }
                }
                TitleSearch.NoMatch -> Message(L("Aucun livre trouvé, essayez un autre titre"), "magnifyingglass")
                is TitleSearch.Failed -> Message(state.reason, "exclamationmark.triangle")
                else -> Unit
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(18.dp)).background(colors.secondaryGroupedBackground)
                    .plainClickable { onChoose(AddBookSource.Manual) }.padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Symbol("square.and.pencil"), null, Modifier.size(22.dp), tint = colors.label)
                Text(L("Ajouter à la main"), style = Shiori.type.body, color = colors.label)
            }
            Spacer(Modifier.size(12.dp))
        }
    }
}

@Composable
private fun Message(text: String, symbol: String) {
    Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol(symbol), null, Modifier.size(16.dp), tint = Shiori.colors.secondaryLabel)
        Text(text, style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel)
    }
}

@Composable
private fun Tile(symbol: String, title: String, badge: String? = null, onClick: () -> Unit) {
    val colors = Shiori.colors
    Column(
        Modifier.size(116.dp).clip(RoundedCornerShape(16.dp)).background(colors.secondaryGroupedBackground).plainClickable(onClick = onClick).padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        Icon(Symbol(symbol), null, Modifier.size(26.dp), tint = colors.label)
        Text(title, style = Shiori.type.footnote, color = colors.label, textAlign = TextAlign.Center, maxLines = 2)
        if (badge != null) {
            Text(
                badge,
                style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                color = colors.purple,
                modifier = Modifier.background(colors.purple.copy(alpha = 0.15f), CircleShape).padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

