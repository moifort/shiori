package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.R
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.components.atoms.OutlinedTag
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import java.net.URLEncoder
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Where a volume to come is pre-ordered on amazon.fr, with Shiori's Associates tag. */
fun DiscoveredVolume.amazonURL(author: String): String {
    val tag = "polyforms09-21"
    val isbn10 = isbn13?.let(::isbn10Of)
    if (isbn10 != null) return "https://www.amazon.fr/dp/$isbn10?tag=$tag"
    val query = URLEncoder.encode(listOf(title, author).filter { it.isNotEmpty() }.joinToString(" "), "UTF-8")
    return "https://www.amazon.fr/s?k=$query&i=stripbooks&tag=$tag"
}

private fun isbn10Of(isbn13: String): String? {
    if (isbn13.length != 13 || !isbn13.startsWith("978")) return null
    val body = isbn13.drop(3).take(9)
    val digits = body.map { it.digitToIntOrNull() ?: return null }
    val sum = digits.mapIndexed { i, d -> d * (10 - i) }.sum()
    val check = (11 - sum % 11) % 11
    return body + if (check == 10) "X" else check.toString()
}

/** The next volume of a saga, on its cover's wash: its date leaf, countdown, and pre-order. */
@Composable
fun SeriesReleaseCard(
    volume: DiscoveredVolume,
    author: String,
    isAudio: Boolean,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
    place: String? = null,
    language: BookLanguage? = null,
    isAwaited: Boolean = false,
) {
    val uri = LocalUriHandler.current
    val book = Book(id = "release-${volume.number}", title = volume.title, authors = listOf(author), format = if (isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK, coverURL = volume.coverURL, status = ReadingStatus.TO_READ)
    val store: Pair<String, Int>? = if (isAudio) volume.audibleURL?.let { it to R.drawable.audible_logo } else volume.amazonURL(author) to R.drawable.amazon_logo
    Box(modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).plainClickable(onClick = onOpen)) {
        CoverBackdrop(volume.coverURL, Modifier.matchParentSize(), ground = Color.Transparent)
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).heightIn(min = 150.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.width(100.dp).fillMaxHeight()) { BookCover(book, 100.dp, showsFormatBadge = false, minHeight = 150.dp, cornerRadius = 0.dp) }
            Column(Modifier.weight(1f).padding(vertical = 12.dp).padding(end = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                val room = if (volume.date == null) 0.dp else 48.dp
                Text(place ?: "$author · ${L("Tome %lld", volume.number)}", style = Shiori.type.caption, color = Color.White.copy(alpha = 0.75f), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(end = room))
                Text(volume.title, style = Shiori.type.headline, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(end = room))
                Row(Modifier.padding(top = 3.dp).height(18.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    volume.date?.let { ReleaseDateText.countdown(it) }?.let { OutlinedTag(it, isFrosted = false) }
                    if (isAudio) OutlinedTag(L("Audio"), isFrosted = false)
                    if (language != null && language.isForeign) OutlinedTag(language.code, isFrosted = false)
                    if (isAwaited) Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(14.dp), tint = Color.White)
                }
                Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
                if (store != null) {
                    Row(
                        Modifier.clip(CircleShape).background(Color.White).plainClickable { uri.openUri(store.first) }.padding(horizontal = 12.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(L("Précommander"), style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = Color.Black, maxLines = 1)
                        Image(painterResource(store.second), null, Modifier.size(24.dp, 12.dp), colorFilter = ColorFilter.tint(Color.Black))
                    }
                }
            }
        }
        volume.date?.let { Box(Modifier.align(Alignment.TopEnd).padding(10.dp)) { ReleaseDateBadge(it, onGlass = true) } }
    }
}

@Preview(showBackground = true)
@Composable
private fun SeriesReleaseCardPreview() = PreviewSurface {
    SeriesReleaseCard(DebugFixtures.announcedVolume, "Kanehito Yamada", isAudio = false, onOpen = {}, modifier = Modifier.padding(16.dp))
}
