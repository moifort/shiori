package com.polyforms.shiori.shared.book

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.R
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.Pill
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/** One cell of a fact grid: a small caps title over a value, tappable to edit. */
data class FactTile(
    val id: String,
    val title: String,
    val value: String?,
    val chips: List<String> = emptyList(),
    val isWide: Boolean = false,
    val monospaced: Boolean = false,
    val placeholder: String = L("Non renseigné"),
    val showsChevron: Boolean = false,
    val action: (() -> Unit)? = null,
)

/** A store a book is found in, drawn as a full-width row under the tiles. */
data class FactLink(val id: String, val title: String, val logo: Int, val url: String)

data class FactGroup(val tiles: List<FactTile>, val columns: Int = 2)

/** Tiles in rows of a group's columns, hairlines between them, on one rounded card. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FactGrid(groups: List<FactGroup>, links: List<FactLink> = emptyList()) {
    val colors = Shiori.colors
    val uri = LocalUriHandler.current
    val rows = buildList {
        for (group in groups.filter { it.tiles.isNotEmpty() }) {
            var current = mutableListOf<FactTile>()
            for (tile in group.tiles) {
                if (tile.isWide) {
                    if (current.isNotEmpty()) add(current to group.columns).also { current = mutableListOf() }
                    add(listOf(tile) to 1)
                } else {
                    current += tile
                    if (current.size == group.columns) add(current to group.columns).also { current = mutableListOf() }
                }
            }
            if (current.isNotEmpty()) add(current to group.columns)
        }
    }
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(colors.separator).border(1.dp, colors.separator, shape),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        rows.forEach { (tiles, columns) ->
            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(1.dp)) {
                tiles.forEachIndexed { index, tile ->
                    val weight = if (index == tiles.lastIndex) (columns - index).toFloat() else 1f
                    Column(
                        Modifier
                            .weight(weight)
                            .fillMaxHeight()
                            .background(colors.secondaryGroupedBackground)
                            .then(if (tile.action != null) Modifier.clickable(onClick = tile.action) else Modifier)
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        Text(
                            tile.title.uppercase(),
                            style = Shiori.type.footnote.copy(letterSpacing = 0.3.sp),
                            color = colors.secondaryLabel,
                        )
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                val style: TextStyle = when {
                                    tile.value == null -> Shiori.type.body
                                    tile.monospaced -> Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum")
                                    else -> Shiori.type.body.copy(fontWeight = FontWeight.SemiBold)
                                }
                                Text(
                                    tile.value ?: tile.placeholder,
                                    style = style,
                                    color = if (tile.value == null) colors.tertiaryLabel else colors.label,
                                    maxLines = 2,
                                )
                                if (tile.showsChevron) Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
                            }
                            tile.chips.forEach { Pill(it, style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold)) }
                        }
                    }
                }
            }
        }
        links.forEach { link ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(colors.secondaryGroupedBackground)
                    .clickable { uri.openUri(link.url) }
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(painterResource(link.logo), null, Modifier.size(30.dp, 22.dp), colorFilter = ColorFilter.tint(colors.label))
                Text(link.title, style = Shiori.type.body.copy(fontWeight = FontWeight.SemiBold), color = colors.label, modifier = Modifier.weight(1f))
                Icon(Symbol("arrow.up.right"), null, Modifier.size(14.dp), tint = colors.tertiaryLabel)
            }
        }
    }
}

/** A fact a tile edits in place. */
enum class BookFact {
    PUBLISHER, FIRST_PUBLISHED_IN, EDITION_YEAR, PAGE_COUNT, ISBN13;

    val title: String
        get() = when (this) {
            PUBLISHER -> L("Éditeur")
            FIRST_PUBLISHED_IN -> L("Première parution")
            EDITION_YEAR -> L("Année d'édition")
            PAGE_COUNT -> L("Pages")
            ISBN13 -> L("ISBN")
        }

    val icon: String
        get() = when (this) {
            PUBLISHER -> "building.2"
            FIRST_PUBLISHED_IN -> "calendar"
            EDITION_YEAR -> "calendar.badge.clock"
            PAGE_COUNT -> "doc.plaintext"
            ISBN13 -> "barcode"
        }

    val isNumeric: Boolean get() = this != PUBLISHER

    /** The edition year is a recording's fact; a printed book shows it only when it has one. */
    fun applies(book: Book): Boolean = this != EDITION_YEAR || book.format == BookFormat.AUDIOBOOK || book.editionYear != null

    fun value(book: Book): String? = when (this) {
        PUBLISHER -> book.publisher
        FIRST_PUBLISHED_IN -> book.firstPublishedIn?.toString()
        EDITION_YEAR -> book.editionYear?.toString()
        PAGE_COUNT -> book.pageCount?.toString()
        ISBN13 -> book.isbn13
    }

    /** The correction a typed value makes; null when the text is not a valid value. */
    fun correction(text: String, book: Book): BookCorrection? {
        val trimmed = text.trim()
        fun <T> change(old: T?, new: T?): Change<T>? = when {
            old == new -> null
            new == null -> Change.Clear
            else -> Change.Set(new)
        }
        return when (this) {
            PUBLISHER -> BookCorrection(publisher = change(book.publisher, trimmed.ifEmpty { null }))
            FIRST_PUBLISHED_IN -> {
                if (trimmed.isNotEmpty() && trimmed.toIntOrNull() == null) return null
                BookCorrection(firstPublishedIn = change(book.firstPublishedIn, trimmed.toIntOrNull()))
            }
            EDITION_YEAR -> {
                if (trimmed.isNotEmpty() && trimmed.toIntOrNull() == null) return null
                BookCorrection(editionYear = change(book.editionYear, trimmed.toIntOrNull()))
            }
            PAGE_COUNT -> {
                if (trimmed.isNotEmpty() && (trimmed.toIntOrNull() ?: 0) < 1) return null
                BookCorrection(pageCount = change(book.pageCount, trimmed.toIntOrNull()))
            }
            ISBN13 -> {
                val digits = trimmed.filter { !it.isWhitespace() && it != '-' }
                if (digits.isNotEmpty() && !isValidIsbn13(digits)) return null
                BookCorrection(isbn13 = change(book.isbn13, digits.ifEmpty { null }))
            }
        }
    }

    companion object {
        /** Thirteen digits whose check digit holds. */
        fun isValidIsbn13(value: String): Boolean {
            if (value.length != 13 || !value.all { it.isDigit() }) return false
            val sum = value.take(12).mapIndexed { i, c -> (c - '0') * if (i % 2 == 0) 1 else 3 }.sum()
            return (10 - sum % 10) % 10 == value.last() - '0'
        }
    }
}

val Book.formatFactValue: String
    get() = if (format == BookFormat.AUDIOBOOK || media.isEmpty()) format.label else "${format.label} · ${BookMedium.label(media).lowercase()}"

val Book.shownAudibleURL: String? get() = if (format == BookFormat.AUDIOBOOK) audibleURL else null
val Book.shownAmazonURL: String? get() = if (format == BookFormat.AUDIOBOOK) null else amazonURL

val Book.storeFactLinks: List<FactLink>
    get() = listOfNotNull(
        shownAudibleURL?.let { FactLink("audible", L("Écouter sur Audible"), R.drawable.audible_logo, it) },
        shownAmazonURL?.let { FactLink("amazon", L("Voir sur Amazon"), R.drawable.amazon_logo, it) },
    )

/** The facts a page that cannot edit shows: a friend's book, a book to come. */
val Book.readOnlyFactTiles: List<FactTile>
    get() = buildList {
        add(FactTile("genre", L("Genre"), genre?.label, chips = subgenres, isWide = true))
        add(FactTile("format", L("Format"), formatFactValue))
        add(FactTile("publisher", L("Éditeur"), publisher))
        add(FactTile("firstPublishedIn", L("Parution"), firstPublishedIn?.toString()))
        val duration = durationLabel
        if (duration != null) add(FactTile("duration", L("Durée"), duration)) else add(FactTile("pageCount", L("Pages"), pageCount?.toString()))
        if (BookFact.EDITION_YEAR.applies(this@readOnlyFactTiles) && editionYear != null) add(FactTile("editionYear", L("Année d'édition"), editionYear.toString()))
        if (format != BookFormat.AUDIOBOOK) add(FactTile("isbn13", L("ISBN"), isbn13, monospaced = true))
    }
