package com.polyforms.shiori.features.series.components.pages

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.components.atoms.setAsideAnimation
import com.polyforms.shiori.shared.components.molecules.ActionToggle
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.iconGesture
import com.polyforms.shiori.shared.components.styles.saturation
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.discover.SagaReleases
import com.polyforms.shiori.features.series.SeriesFriend
import com.polyforms.shiori.features.series.components.organisms.SeriesFan
import com.polyforms.shiori.features.series.components.organisms.SeriesHero
import com.polyforms.shiori.features.series.components.organisms.SeriesPosterRail
import com.polyforms.shiori.features.series.components.organisms.SeriesReleaseCard
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookSeries
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesOpinion
import com.polyforms.shiori.shared.Volume
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.authorDestinations
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.EmptyStateAction
import com.polyforms.shiori.shared.components.molecules.Figure
import com.polyforms.shiori.shared.components.molecules.Figures
import com.polyforms.shiori.shared.components.molecules.FiguresLine
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.datedUpTo
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.launch
import java.text.Normalizer
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface SeriesAction {
    data class OpenBook(val book: Book) : SeriesAction
    data object Rate : SeriesAction
    data object EditGenre : SeriesAction
    /** The bell: the saga followed again, or set aside. */
    data class SetFollowed(val followed: Boolean) : SeriesAction
    data class OpenAuthor(val author: AuthorDestination) : SeriesAction
    /** A volume the reader lacks, announced or out, on its own page. */
    data class OpenAnnounced(val volume: DiscoveredVolume) : SeriesAction
    data class Add(val volume: Volume, val author: String, val format: BookFormat, val status: ReadingStatus) : SeriesAction
    data object Retry : SeriesAction
    data object DeclareVolumeCount : SeriesAction
}

/** The formats a volume can be added in: the saga's own (paper when heard), and audio. */
val BookFormat.takenAs: List<BookFormat> get() = listOf(if (this == BookFormat.AUDIOBOOK) BookFormat.BOOK else this, BookFormat.AUDIOBOOK)

/**
 * A saga's page: the fanned hero, its progress and rating, the next release, the volumes. The
 * missing volumes are dimmed: a tap opens their page and a long press offers to add them. Set
 * aside, every cover of the saga turns black and white, and "Suivre" takes the stars' room.
 */
@Composable
fun SeriesPage(
    series: BookSeries?,
    owned: List<Book>,
    opinion: SeriesOpinion?,
    isLoading: Boolean,
    errorMessage: String?,
    language: BookLanguage?,
    friend: SeriesFriend?,
    isFollowed: Boolean,
    addingTitle: String?,
    releases: SagaReleases?,
    takenFormat: BookFormat,
    announcedVolume: (Volume) -> DiscoveredVolume?,
    /** The page of a volume out the reader lacks; null for an annex. */
    unownedVolume: (Volume) -> DiscoveredVolume? = { null },
    onAction: suspend (SeriesAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: SeriesAction) {
        scope.launch { onAction(action) }
    }
    when {
        isLoading && series == null && owned.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        series != null -> Catalogue(series, owned, opinion, language, friend, isFollowed, addingTitle, releases, takenFormat, announcedVolume, unownedVolume, onAction, ::act)
        else -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            EmptyState(
                "square.stack.3d.up.slash",
                L("Série non cataloguée"),
                errorMessage ?: L("Shiori n'a pas réussi à constituer le catalogue de cette série. Réessayez plus tard, ou scannez la couverture d'un de ses tomes."),
                primary = EmptyStateAction(L("Réessayer"), "arrow.clockwise") { onAction(SeriesAction.Retry) },
                secondary = if (owned.isEmpty() || friend != null) null else EmptyStateAction(L("Indiquer le nombre de tomes"), "number") { onAction(SeriesAction.DeclareVolumeCount) },
            )
        }
    }
}

private val currentYear: Int get() = LocalDate.now().year

@Composable
private fun Catalogue(
    series: BookSeries,
    owned: List<Book>,
    opinion: SeriesOpinion?,
    language: BookLanguage?,
    friend: SeriesFriend?,
    isFollowed: Boolean,
    addingTitle: String?,
    releases: SagaReleases?,
    takenFormat: BookFormat,
    announcedVolume: (Volume) -> DiscoveredVolume?,
    unownedVolume: (Volume) -> DiscoveredVolume?,
    onAction: suspend (SeriesAction) -> Unit,
    act: (SeriesAction) -> Unit,
) {
    // Following is the reader's: not on a friend's shelf, nor over a saga they hold nothing of.
    val followsHere = friend == null && owned.isNotEmpty()
    // The reader stopped following the saga: said by the slashed bell and in black and white on
    // every cover, with no pill to push the hero down.
    val isSetAside = followsHere && !isFollowed
    val saturation by animateFloatAsState(if (isSetAside) 0f else 1f, setAsideAnimation(), label = "setAside")
    val datedUpTo = series.spine.datedUpTo(language, series.catalogedAt)
    val published = series.spine.filter { it.counts(currentYear, language, datedUpTo) }
    val read = published.count { v -> owned.any { v.matches(it) && it.status == ReadingStatus.READ } }
    val heldNumbers = owned.mapNotNull { if (it.series?.kind == VolumeKind.MAIN) it.series.volume else null }.toSet()
    val colors = Shiori.colors
    Column(Modifier.fillMaxSize().background(colors.groupedBackground).verticalScroll(rememberScrollState())) {
        val authorDestination = owned.flatMap { it.authorDestinations }.firstOrNull { it.name == series.author } ?: owned.firstOrNull()?.authorDestinations?.firstOrNull()
        val fanVolumes = series.spine.map { volume ->
            owned.firstOrNull(volume::matches) ?: Book(
                id = volume.id,
                title = language?.let { volume.release(it) }?.title ?: volume.title,
                authors = listOf(series.author),
                format = if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
                coverURL = language?.let { volume.release(it) }?.coverURL,
                status = ReadingStatus.TO_READ,
            )
        }
        SeriesHero(
            series.name,
            series.author,
            SeriesFan.of(fanVolumes, fanVolumes.indexOfFirst { it.coverURL != null }.coerceAtLeast(0)),
            language,
            onOpenAuthor = authorDestination?.let { a -> { act(SeriesAction.OpenAuthor(AuthorDestination(a.key, a.name))) } },
            isSetAside = isSetAside,
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                ProgressCapsule(read, published.size, Modifier.weight(1f))
                // Set aside, "Suivre" takes the stars' room: the saga is rated again once followed.
                if (!isSetAside) RatingCapsule(opinion, friend != null) { act(SeriesAction.Rate) }
                if (followsHere) {
                    // The bell on white while followed, slashed on glass once set aside. Setting it
                    // aside asks first, as "Supprimer" does; following it again does not.
                    ActionToggle(
                        isOn = isFollowed,
                        symbol = "bell",
                        turnOnLabel = L("Suivre"),
                        turnOffLabel = L("Ne plus suivre"),
                        offSymbol = SeriesState.UNFOLLOWED.symbol,
                        size = 50.dp,
                        gesture = IconGesture.SWING,
                        turnOffConfirmation = L("Ne plus suivre la série ?"),
                    ) { followed -> onAction(SeriesAction.SetFollowed(followed)) }
                }
            }
        }
        Column(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
                val next = releases?.next
                if (friend == null && next != null && next.number !in heldNumbers) {
                    Box(Modifier.saturation(saturation)) {
                        SeriesReleaseCard(next, series.author, series.isAudio, onOpen = { act(SeriesAction.OpenAnnounced(next)) }, language = language)
                    }
                }
                SeriesFigures(series, owned, read, published.size, language, datedUpTo)
            }
            series.description?.let { BookSynopsisBlock(it) }
            // None is ringed: a saga's page is about the saga, no volume of it is open here. Set
            // aside, every cover of the saga turns black and white, the hero's and the volumes'.
            Column(Modifier.saturation(saturation), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                SeriesPosterRail(L("Tomes"), posters(series.spine, owned), { it.id }) { poster ->
                    PosterView(poster, series, language, friend, addingTitle, releases, takenFormat, datedUpTo, announcedVolume, unownedVolume, act)
                }
                val annexes = annexPosters(series.relatedWorks, owned)
                if (annexes.isNotEmpty()) {
                    SeriesPosterRail(L("Hors-série"), annexes, { it.id }) { poster ->
                        PosterView(poster, series, language, friend, addingTitle, releases, takenFormat, datedUpTo, announcedVolume, unownedVolume, act)
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Informations"))
                FactGrid(listOf(FactGroup(dayTiles(owned), 3), FactGroup(factTiles(series, owned, friend) { act(SeriesAction.EditGenre) })))
                if (series.isProvisional) {
                    Text(L("Catalogue provisoire, dessiné d'après le nombre de tomes que vous avez indiqué."), style = Shiori.type.footnote, color = colors.secondaryLabel)
                }
            }
        }
    }
}

private data class Poster(val id: String, val volume: Volume, val book: Book?)

private fun posters(volumes: List<Volume>, owned: List<Book>): List<Poster> = volumes.flatMap { volume ->
    val books = owned.filter(volume::matches)
    if (books.isEmpty()) listOf(Poster("missing-${volume.id}", volume, null)) else books.map { Poster(it.id, volume, it) }
}

private fun folded(title: String) = Normalizer.normalize(title.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")

private fun annexPosters(volumes: List<Volume>, owned: List<Book>): List<Poster> {
    val annexes = owned.filter { it.series?.isAnnex == true }
    val placed = mutableSetOf<String>()
    val posters = volumes.flatMap { volume ->
        val books = annexes.filter { volume.matches(it) || folded(it.title) == folded(volume.title) }
        placed += books.map { it.id }
        if (books.isEmpty()) listOf<Pair<Int?, Poster>>(null to Poster("missing-${volume.id}", volume, null)) else books.map { it.series?.annexNumber to Poster(it.id, volume, it) }
    }.toMutableList()
    for (book in annexes) if (book.id !in placed) {
        posters += book.series?.annexNumber to Poster(book.id, Volume(null, book.title, book.firstPublishedIn, book.series?.kind ?: VolumeKind.SPIN_OFF), book)
    }
    return (posters.filter { it.first != null }.sortedBy { it.first } + posters.filter { it.first == null }).map { it.second }
}

private fun caption(volume: Volume) = volume.number?.let { L("Tome %lld", it) } ?: volume.kind.label

private fun caption(book: Book, volume: Volume): String {
    val number = book.series?.annexNumber
    if (volume.kind == VolumeKind.MAIN || number == null) return caption(volume)
    return L("Hors-série %lld", number)
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PosterView(
    poster: Poster,
    series: BookSeries,
    language: BookLanguage?,
    friend: SeriesFriend?,
    addingTitle: String?,
    releases: SagaReleases?,
    takenFormat: BookFormat,
    datedUpTo: Int?,
    announcedVolume: (Volume) -> DiscoveredVolume?,
    unownedVolume: (Volume) -> DiscoveredVolume?,
    act: (SeriesAction) -> Unit,
) {
    val book = poster.book
    val volume = poster.volume
    if (book != null) {
        Box(Modifier.plainClickable { act(SeriesAction.OpenBook(book)) }) { PosterCover(book, caption(book, volume), showsEditionTags = false) }
        return
    }
    val release = language?.let { volume.release(it) }
    val title = release?.title ?: volume.title
    val forthcoming = volume.isForthcoming(currentYear, language, datedUpTo)
    // Its day as the edition, the release watch or the card above dates it, else "Annoncé": an
    // announced volume never shows a bare number.
    val date = release?.date
        ?: announcedVolume(volume)?.date
        ?: releases?.next?.takeIf { it.number == volume.number && volume.kind == VolumeKind.MAIN }?.date
    val day = if (forthcoming) date?.let { ReleaseDateText.short(it) } ?: L("Annoncé") else null
    val coverURL = release?.coverURL
        ?: (if (forthcoming) announcedVolume(volume)?.coverURL else null)
        ?: releases?.next?.takeIf { it.number == volume.number && volume.kind == VolumeKind.MAIN }?.coverURL
    var menu by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    // Out, a tap opens the volume's page and a long press offers to add it; an annex has no page,
    // a tap offers to add it. Announced, a tap opens its page once the release watch found one.
    val page = if (forthcoming) announcedVolume(volume) else unownedVolume(volume)
    val adds = !forthcoming && friend == null
    Box(
        Modifier.then(
            when {
                page != null -> Modifier.combinedClickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    enabled = addingTitle == null || forthcoming,
                    onLongClick = if (adds) ({
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        menu = true
                    }) else null,
                ) { act(SeriesAction.OpenAnnounced(page)) }
                adds -> Modifier.plainClickable(enabled = addingTitle == null) { menu = true }
                else -> Modifier
            },
        ),
    ) {
        if (day != null && coverURL == null) {
            BlankPoster(day)
        } else {
            PosterCover(
                Book(id = volume.id, title = title, authors = listOf(series.author), format = if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK, coverURL = coverURL, status = ReadingStatus.TO_READ),
                day ?: caption(volume),
                Modifier.alpha(if (day == null) 0.45f else 1f),
                showsEditionTags = false,
                dimming = if (day == null) 0.12 else 0.5,
            )
        }
        if (addingTitle == volume.title) CircularProgressIndicator(Modifier.align(Alignment.Center))
        if (adds) {
            MenuEntries(
                takenFormat.takenAs.flatMap { format ->
                    listOf(
                        MenuEntry.Item("${format.label} · ${if (format == BookFormat.AUDIOBOOK) L("À écouter") else L("À lire")}", "bookmark.fill") { act(SeriesAction.Add(volume, series.author, format, ReadingStatus.TO_READ)) },
                        MenuEntry.Item("${format.label} · ${if (format == BookFormat.AUDIOBOOK) L("Déjà écouté") else L("Déjà lu")}", "checkmark") { act(SeriesAction.Add(volume, series.author, format, ReadingStatus.READ)) },
                    )
                },
                menu,
            ) { menu = false }
        }
    }
}

@Composable
private fun BlankPoster(caption: String) {
    val shape = RoundedCornerShape(8.dp)
    Box(
        Modifier.size(102.dp, 153.dp).clip(shape)
            .background(Brush.linearGradient(listOf(Color(0xFF3B3B3B), Color(0xFF242424))))
            .border(1.dp, Color.White.copy(alpha = 0.22f), shape),
    ) {
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.45f to Color.Transparent, 0.95f to Color.Black.copy(alpha = 0.35f))))
        Text(caption, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 9.dp))
    }
}

@Composable
private fun ProgressCapsule(read: Int, total: Int, modifier: Modifier = Modifier) {
    val fraction = if (total > 0) minOf(read, total).toFloat() / total else 0f
    val number = NumberFormat.getIntegerInstance()
    Row(
        modifier.height(50.dp).shadow(11.dp, CircleShape).clip(CircleShape).background(Color.White).padding(start = 20.dp, end = 18.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.weight(1f).widthIn(min = 40.dp).height(6.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.16f))) {
            Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(Color.Black, CircleShape))
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text(number.format(read), style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color.Black)
            Text("/${number.format(total)}", style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.Black.copy(alpha = 0.5f), modifier = Modifier.padding(bottom = 2.dp))
        }
    }
}

@Composable
private fun RatingCapsule(opinion: SeriesOpinion?, isFriend: Boolean, onRate: () -> Unit) {
    val rating = opinion?.rating
    val favorite = opinion?.favorite == true
    val shows = if (isFriend) rating != null || favorite else rating != null || !favorite
    if (!shows) return
    Row(
        Modifier.height(50.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
            .then(if (!isFriend) Modifier.plainClickable(onClick = onRate) else Modifier)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when {
            rating != null -> Box(Modifier.iconGesture(IconGesture.HOP, rating)) { RatingStars(rating, size = 14.dp, monochrome = true, tint = Color.White) }
            !isFriend -> {
                Icon(Symbol("star"), null, Modifier.size(16.dp), tint = Color.White)
                Text(L("Noter"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.White)
            }
        }
        if (isFriend && favorite) Icon(Symbol("heart.fill"), L("Coup de cœur"), Modifier.size(16.dp), tint = Color.White)
    }
}

@Composable
private fun SeriesFigures(series: BookSeries, owned: List<Book>, read: Int, published: Int, language: BookLanguage?, datedUpTo: Int?) {
    val number = NumberFormat.getIntegerInstance()
    val main = owned.filter { it.series?.kind == VolumeKind.MAIN }
    val announced = series.spine.count { it.isForthcoming(currentYear, language, datedUpTo) }
    val items = mutableListOf(
        Figure(number.format(read), if (series.isAudio) L("écoutés") else L("lus")),
        Figure(number.format(main.count { it.status == ReadingStatus.TO_READ }), L("à lire")),
        Figure(number.format(published), L("tomes")),
    )
    if (announced > 0) items += Figure(number.format(announced), if (announced == 1) L("annoncé") else L("annoncés"))
    val minutes = owned.sumOf { it.durationMinutes ?: 0 }
    val pages = owned.sumOf { it.pageCount ?: 0 }
    if (series.isAudio && minutes > 0) items += Figure("${number.format(minutes / 60)}h", L("d'écoute"))
    else if (pages > 0) items += Figure(Figures.compact(pages), L("pages"))
    FiguresLine(items)
}

private fun dayTiles(owned: List<Book>): List<FactTile> {
    fun day(date: Instant?) = date?.let { DateText.dayMonthShort(DateText.local(it)) }
    val main = owned.filter { it.series?.kind == VolumeKind.MAIN }
    val finished = if (main.isNotEmpty() && main.all { it.status == ReadingStatus.READ }) main.mapNotNull { it.finishedAt }.maxOrNull() else null
    return listOf(
        FactTile("addedAt", L("Ajoutée"), day(owned.mapNotNull { it.addedAt }.minOrNull()), placeholder = "—"),
        FactTile("startedAt", L("Commencée"), day(owned.mapNotNull { it.startedAt }.minOrNull()), placeholder = "—"),
        FactTile("finishedAt", L("Terminée"), day(finished), placeholder = "—"),
    )
}

private fun factTiles(series: BookSeries, owned: List<Book>, friend: SeriesFriend?, onEditGenre: () -> Unit): List<FactTile> {
    val volume = owned.firstOrNull()
    val editable = friend == null && volume != null
    val firstYear = series.spine.mapNotNull { it.publishedIn }.minOrNull()
    val format = volume?.format ?: if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
    val publisher = owned.mapNotNull { it.publisher }.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key
    val tiles = mutableListOf(
        FactTile("genre", L("Genre"), volume?.genre?.label, chips = volume?.subgenres.orEmpty(), isWide = true, showsChevron = editable, action = if (editable) onEditGenre else null),
        FactTile("format", L("Format"), format.label),
        FactTile("publisher", L("Éditeur"), publisher),
        FactTile("firstPublishedIn", L("Parution"), firstYear?.let { L("Depuis %@", it.toString()) }),
    )
    val minutes = owned.sumOf { it.durationMinutes ?: 0 }
    val pages = owned.sumOf { it.pageCount ?: 0 }
    tiles += if (series.isAudio) {
        FactTile("duration", L("Durée"), if (minutes > 0) "${minutes / 60} h" else null)
    } else {
        FactTile("pageCount", L("Pages"), if (pages > 0) NumberFormat.getIntegerInstance().format(pages) else null)
    }
    return tiles
}

@Preview(showBackground = true)
@Composable
private fun SeriesPagePreview() = PreviewSurface {
    SeriesPage(
        series = DebugFixtures.seriesCatalogue,
        owned = listOf(DebugFixtures.reading[2]),
        opinion = null,
        isLoading = false,
        errorMessage = null,
        language = com.polyforms.shiori.shared.BookLanguage.FR,
        friend = null,
        isFollowed = true,
        addingTitle = null,
        releases = null,
        takenFormat = com.polyforms.shiori.shared.BookFormat.MANGA,
        announcedVolume = { null },
    ) {}
}
