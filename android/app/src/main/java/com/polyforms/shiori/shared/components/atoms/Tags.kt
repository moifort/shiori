package com.polyforms.shiori.shared.components.atoms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.ultraThinDark

/** A headphones disc on a cover: the book is a recording. */
@Composable
fun AudiobookBadge(size: Dp = 18.dp) {
    val colors = Shiori.colors
    Box(
        Modifier.size(size).background(if (colors.isDark) colors.label.copy(alpha = 0.85f) else colors.gray, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol("headphones"), L("Livre audio"), Modifier.size(size * 0.58f), tint = colors.background)
    }
}

/** Binoculars beside a book followed for its release. */
@Composable
fun AwaitedMark() {
    Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(16.dp), tint = Shiori.colors.secondaryLabel)
}

/** White capitals in a white outline on a cover: "EN", "AUDIO". */
@Composable
fun OutlinedTag(text: String, isFrosted: Boolean = true) {
    val shape = RoundedCornerShape(3.dp)
    Text(
        text.uppercase(),
        style = Shiori.type.caption2.copy(fontWeight = FontWeight.Bold),
        color = Color.White.copy(alpha = 0.9f),
        modifier = Modifier
            .then(if (isFrosted) Modifier.ultraThinDark(shape) else Modifier)
            .border(1.dp, Color.White.copy(alpha = 0.75f), shape)
            .padding(horizontal = 4.dp, vertical = 1.dp),
    )
}

/** The tags a cover wears: a foreign language, a recording. Nothing for a book in the phone's. */
@Composable
fun CoverTags(language: BookLanguage?, isAudio: Boolean, isFrosted: Boolean = true) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        if (language != null && language.isForeign) OutlinedTag(language.code, isFrosted)
        if (isAudio) OutlinedTag(L("Audio"), isFrosted)
    }
}

@Composable
fun CoverTags(book: Book, isFrosted: Boolean = true) =
    CoverTags(book.language, book.format == BookFormat.AUDIOBOOK, isFrosted)

fun coverTagsAreEmpty(language: BookLanguage?, isAudio: Boolean): Boolean = !isAudio && language?.isForeign != true

/** "EN" in a grey lozenge beside a title. */
@Composable
fun LanguageTag(language: BookLanguage) {
    Text(
        language.code,
        style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
        color = Shiori.colors.secondaryLabel,
        modifier = Modifier
            .background(Shiori.colors.fill, RoundedCornerShape(4.dp))
            .padding(horizontal = 4.dp, vertical = 1.dp),
    )
}

/** A white bar on a cover, how far the reader got. */
@Composable
fun ProgressBar(fraction: Double, width: Dp = 40.dp) {
    Box(Modifier.size(width, 4.dp).background(Color.White.copy(alpha = 0.3f), CircleShape)) {
        Box(
            Modifier.size(width * fraction.coerceIn(0.0, 1.0).toFloat(), 4.dp).background(Color.White, CircleShape),
        )
    }
}

val ReadingStatus.tint: Color
    @Composable get() = when (this) {
        ReadingStatus.TO_READ -> Shiori.colors.orange
        ReadingStatus.READING -> Shiori.colors.blue
        ReadingStatus.READ -> Shiori.colors.green
        ReadingStatus.DROPPED -> Shiori.colors.red
    }

/** A status disc on a cover's corner. */
@Composable
fun ReadingStatusBadge(status: ReadingStatus) = CoverBadge(status.symbol, status.tint)

@Composable
fun CoverBadge(symbol: String, tint: Color) {
    Box(
        Modifier
            .size(18.dp)
            .background(tint, CircleShape)
            .border(1.5.dp, Shiori.colors.secondaryGroupedBackground, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol(symbol), null, Modifier.size(9.dp), tint = Color.White)
    }
}

/** A tinted capsule under a row: a genre, a volume. */
@Composable
fun RowChip(text: String, tint: Color, symbol: String? = null) {
    Row(
        Modifier.background(tint.copy(alpha = 0.15f), CircleShape).padding(horizontal = 6.dp, vertical = 1.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (symbol != null) Icon(Symbol(symbol), null, Modifier.size(11.dp), tint = tint)
        Text(text, style = Shiori.type.caption, color = tint)
    }
}

/** A saga's name, with headphones when it is heard. */
@Composable
fun SagaName(name: String, isAudio: Boolean, style: androidx.compose.ui.text.TextStyle = Shiori.type.body) {
    Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(name, style = style, color = Shiori.colors.label)
        if (isAudio) {
            Icon(Symbol("headphones"), L("Livre audio"), Modifier.size(14.dp), tint = Shiori.colors.secondaryLabel)
        }
    }
}

/** A shelf filter's label: an icon and a word. */
@Composable
fun ShelfFilterLabel(symbol: String, title: String) {
    Row(
        Modifier.padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Symbol(symbol), null, Modifier.size(16.dp))
        Text(title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium))
    }
}
