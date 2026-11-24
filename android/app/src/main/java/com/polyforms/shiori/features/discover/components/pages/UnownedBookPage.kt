package com.polyforms.shiori.features.discover.components.pages

import com.polyforms.shiori.shared.platform.TabBarClearance
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.R
import com.polyforms.shiori.features.discover.components.organisms.UnownedBookActionsMenu
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactLink
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.SeriesVolumesRow
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.components.molecules.AddMenuButton
import com.polyforms.shiori.shared.components.molecules.AddMenuSize
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.MessageBubble
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionShape
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.actionLabelStyle
import com.polyforms.shiori.shared.components.styles.iconGesture
import com.polyforms.shiori.shared.components.styles.refusalShake
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ScreenBar
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Where a book the reader does not hold is ordered: the recording on Audible, the printed edition on Amazon. */
data class UnownedBookStore(val url: String, val isAudible: Boolean) {
    val logo: Int get() = if (isAudible) R.drawable.audible_logo else R.drawable.amazon_logo

    /** The link closing the facts, as a book's page words it. */
    val factLink: FactLink
        get() = if (isAudible) FactLink("audible", L("Écouter sur Audible"), logo, url) else FactLink("amazon", L("Voir sur Amazon"), logo, url)
}

/** What the "+" of a book not in the library makes of it: on the pile, read already, or on the wishlist. */
enum class UnownedBookAddition { PILE, READ, WISHLIST }

/**
 * What the bell asks before it falls silent, when giving up cannot be undone from the page: an
 * edition awaited stops being watched for good.
 */
data class BellConfirmation(val title: String, val message: String, val action: String)

/** The height of the hero's buttons, the saga page's. */
private val ButtonHeight: Dp = 50.dp

/**
 * A book that is not in the reader's library — a volume announced or out, an edition awaited —
 * opened from "Nouveautés", Découvrir or a saga, and drawn as the reader's own book page is, so
 * nothing new is to be learnt: the hero over the cover's colours, then the summary, the saga, the
 * facts. What it adds is in the hero alone, its first button always white with its label and icon,
 * the others round on glass: the day as a calendar leaf on glass in its corner while it is to
 * come, how long is left tagged after the format, and the saga page's row of actions — the white
 * button that orders it from its store, the "+" once it is out, which opens the suggestion's menu
 * where more than the pile is offered, and the bell that alerts on the day while it is to come,
 * which swings when tapped. Pure and previewable.
 */
@Composable
fun UnownedBookPage(
    /** The book as described, or as the look on the web knows it until then. */
    book: Book,
    /** `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; null for one announced with no date. */
    releaseDate: String?,
    store: UnownedBookStore?,
    /** Whether the bell alerts on the day. */
    isAlerted: Boolean,
    onToggleBell: () -> Unit,
    isDescribing: Boolean = false,
    /** Asked before the bell falls silent; null silences it at once. */
    bellConfirmation: BellConfirmation? = null,
    /** Said on the detail line: once added, once out. */
    state: BookState? = null,
    /** Where the edition stands, as an outlined tag beside the format's: "Pas annoncé" while nothing is. */
    stateTag: String? = null,
    /** Whether it is out, when its store said so; null reads it off the date. */
    isOut: Boolean? = null,
    /** Null where the reader has the book already: no "+". None either while the book is to come. */
    isAdded: Boolean? = null,
    /** Tiles heading the facts: the title in its own language. */
    leadingTiles: List<FactTile> = emptyList(),
    sagaName: String? = null,
    sagaVolumes: List<SeriesStripItem> = emptyList(),
    /** The volume of the row the page is about, ringed: the reader's copy an edition is awaited of. */
    currentVolumeId: String? = null,
    /** What the "+" offers: one, it adds at once; more, it opens a menu. */
    additions: List<UnownedBookAddition> = listOf(UnownedBookAddition.PILE),
    onAdd: suspend (UnownedBookAddition) -> Unit = {},
    /**
     * Whether the book is on the wishlist, once it is out: "+ Ajouter" then offers it and says
     * "Envie" once there. Null draws the "+" alone.
     */
    isWished: Boolean? = null,
    onToggleWish: suspend () -> Unit = {},
    /** What the "+" made of the book, said in its capsule; a second tap undoes it. */
    taken: TakenState? = null,
    onUndo: suspend () -> Unit = {},
    /** Bumped by the caller on each refusal: the hero's buttons shake. */
    refusals: Int = 0,
    onOpenSaga: () -> Unit = {},
    onOpenVolume: (Book) -> Unit = {},
    /** The page of a volume of the saga the reader lacks. Null opens the saga. */
    onOpenLacking: ((DiscoveredVolume) -> Unit)? = null,
    /**
     * "Retirer", at the end of the hero's row, asked first: a book wished for leaves the list, an
     * edition awaited stops being watched. Null draws no button.
     */
    onNoLongerInterested: (suspend () -> Unit)? = null,
    /** "Couverture" in the "…" of the bar: another cover picked for the book, for every reader. */
    onChooseCover: (() -> Unit)? = null,
    /** The friend the book was wished for or awaited at: their first name over their word on it. */
    recommendedBy: String? = null,
) {
    val scope = rememberCoroutineScope()
    var adding by remember { mutableStateOf(false) }
    var rings by remember { mutableIntStateOf(0) }
    var confirmsSilence by remember { mutableStateOf(false) }
    // To come, unless its store says it is out: an edition out may carry no date, or only its year.
    val isUpcoming = isOut?.let { !it } ?: (releaseDate?.let { ReleaseDateText.isUpcoming(it) } ?: true)
    // The "+", once the book is out: whether it is on the pile already.
    val offeredAddition = if (isUpcoming) null else isAdded

    // The row's first button, white with its label and icon: the store, else the "+", else the bell, else "Retirer".
    val lead = when {
        store != null -> Lead.STORE
        offeredAddition != null -> Lead.ADD
        isUpcoming -> Lead.BELL
        onNoLongerInterested != null -> Lead.REMOVE
        else -> null
    }

    fun add(addition: UnownedBookAddition) {
        adding = true
        scope.launch {
            onAdd(addition)
            adding = false
        }
    }

    fun ring() {
        rings += 1
        onToggleBell()
    }

    /** The choices of the "+": the wishlist only where no "Envies" holds it. */
    fun additionEntries(withWish: Boolean): List<MenuEntry> = buildList {
        val audio = book.format == BookFormat.AUDIOBOOK
        if (UnownedBookAddition.PILE in additions) add(MenuEntry.Item(if (audio) L("À écouter") else L("À lire"), "bookmark.fill") { add(UnownedBookAddition.PILE) })
        if (UnownedBookAddition.READ in additions) add(MenuEntry.Item(if (audio) L("Déjà écouté") else L("Déjà lu"), "checkmark") { add(UnownedBookAddition.READ) })
        if (withWish && UnownedBookAddition.WISHLIST in additions) {
            add(MenuEntry.Divider)
            add(MenuEntry.Item(L("Ajouter à la liste d'envies"), "bookmark") { add(UnownedBookAddition.WISHLIST) })
        }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            BookHero(
                book,
                state = state,
                stateTag = stateTag,
                showsLength = false,
                // The day pinned in the corner while it is to come only: once out, the detail line says when.
                releaseDate = if (isUpcoming) releaseDate else null,
                countdown = if (isUpcoming) releaseDate?.let { ReleaseDateText.countdown(it) } else null,
            ) {
                Row(Modifier.refusalShake(refusals), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (store != null) StoreButton(store, isUpcoming)
                    if (offeredAddition != null && isWished != null) {
                        // "+ Ajouter", as on a prize's page: its menu holds the pile, the books read and
                        // the wish list, and its capsule says the choice made; a second tap undoes it.
                        AddMenuButton(
                            entries = additionEntries(withWish = false) + MenuEntry.Divider +
                                MenuEntry.Item(L("Ajouter à la liste d'envies"), "bookmark") { scope.launch { onToggleWish() } },
                            size = AddMenuSize.PAGE,
                            isRound = store != null,
                            done = taken ?: if (isWished) TakenState.Wished else null,
                            isWorking = adding,
                            onUndo = {
                                if (taken == null && isWished) {
                                    scope.launch { onToggleWish() }
                                } else {
                                    adding = true
                                    scope.launch {
                                        onUndo()
                                        adding = false
                                    }
                                }
                            },
                        )
                    } else if (offeredAddition != null && additions.size > 1) {
                        AddMenu(offeredAddition, lead == Lead.ADD, adding, additionEntries(withWish = true))
                    } else if (offeredAddition != null) {
                        AsyncRoundButton(
                            title = if (offeredAddition) L("Ajouté") else L("Ajouter"),
                            symbol = if (offeredAddition) "checkmark" else "plus",
                            isPrimary = lead == Lead.ADD,
                            enabled = !offeredAddition,
                        ) { onAdd(UnownedBookAddition.PILE) }
                    }
                    // Nothing left to alert on once it is out.
                    if (isUpcoming) {
                        Bell(isAlerted, isAlone = lead == Lead.BELL, rings = rings) {
                            if (isAlerted && bellConfirmation != null) confirmsSilence = true else ring()
                        }
                    }
                    if (onNoLongerInterested != null && !isUpcoming && taken == null) {
                        AsyncRoundButton(
                            title = L("Retirer"),
                            symbol = "bookmark.slash",
                            isPrimary = lead == Lead.REMOVE,
                            confirmation = L("Retirer de la liste d'envies ?"),
                            action = onNoLongerInterested,
                        )
                    }
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = TabBarClearance),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                // The summary once the model wrote it; nothing while it writes, the bar saying so.
                if (!isDescribing) book.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
                if (sagaName != null && sagaVolumes.isNotEmpty()) {
                    // The row with this book drawn in its own place, its cover bright and ringed.
                    val number = book.series?.volume
                    val volumes = if (currentVolumeId != null || number == null) {
                        sagaVolumes
                    } else {
                        sagaVolumes.map { item -> if (item is SeriesStripItem.Missing && item.number == number) SeriesStripItem.Owned(book) else item }
                    }
                    SeriesVolumesRow(sagaName, volumes, currentVolumeId ?: book.id, onOpenSaga, onOpenVolume, onOpenLacking)
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Informations"))
                    // The day it is out in full rather than its year.
                    val tiles = book.readOnlyFactTiles.map { tile ->
                        if (tile.id == "firstPublishedIn" && releaseDate != null) tile.copy(value = ReleaseDateText.full(releaseDate)) else tile
                    }
                    FactGrid(listOf(FactGroup(leadingTiles + tiles)), listOfNotNull(store?.factLink))
                }
                // Who recommended it, as the page of a book in the library says it.
                if (recommendedBy != null) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        RowHeader(L("Commentaires"))
                        MessageBubble(L("Je te le conseille."), sender = recommendedBy)
                    }
                }
            }
        }
        // The bar's buttons float over the page as it scrolls, as on a book's.
        ScreenBar {
            if (onChooseCover != null) UnownedBookActionsMenu(onChooseCover)
        }
        GeneratingPillHost(isDescribing)
    }
    if (confirmsSilence && bellConfirmation != null) {
        // Asked from the bell, as a saga's deletion is.
        ConfirmationSheet(
            bellConfirmation.title,
            listOf(ConfirmationChoice(bellConfirmation.action, destructive = true) { ring() }),
            bellConfirmation.message,
        ) { confirmsSilence = false }
    }
}

private enum class Lead { STORE, ADD, BELL, REMOVE }

/**
 * The white button of the saga page's hero, at its content's width: "Précommander" while the book
 * is to come, "Commander" once out, with its store's logo.
 */
@Composable
private fun StoreButton(store: UnownedBookStore, isUpcoming: Boolean) {
    val uri = LocalUriHandler.current
    ActionButton(onClick = { uri.openUri(store.url) }, height = ButtonHeight, isRaised = true) {
        Text(if (isUpcoming) L("Précommander") else L("Commander"), style = actionLabelStyle(ButtonHeight), color = LocalContentColor.current, maxLines = 1)
        Image(painterResource(store.logo), null, Modifier.width(if (store.isAudible) 30.dp else 44.dp).height(16.dp))
    }
}

/** The suggestion's "+": on the pile, read already, or on the wishlist; a tick once added. */
@Composable
private fun AddMenu(isAdded: Boolean, isPrimary: Boolean, adding: Boolean, entries: List<MenuEntry>) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        ActionButton(
            onClick = { expanded = true },
            fill = if (isPrimary) ActionFill.WHITE else ActionFill.GLASS,
            shape = if (isPrimary) ActionShape.CAPSULE else ActionShape.CIRCLE,
            height = ButtonHeight,
            isRaised = isPrimary,
            enabled = !isAdded && !adding,
            contentDescription = if (isAdded) L("Ajouté") else L("Ajouter"),
        ) {
            if (adding) {
                CircularProgressIndicator(Modifier.size(18.dp), color = LocalContentColor.current, strokeWidth = 2.dp)
            } else {
                Icon(Symbol(if (isAdded) "checkmark" else "plus"), null, Modifier.size(20.dp), tint = LocalContentColor.current)
            }
            if (isPrimary) Text(if (isAdded) L("Ajouté") else L("Ajouter"), style = actionLabelStyle(ButtonHeight), color = LocalContentColor.current, maxLines = 1)
        }
        com.polyforms.shiori.shared.platform.MenuEntries(entries, expanded) { expanded = false }
    }
}

/**
 * Alerts on the day, or falls silent: a tap swings it as a bell rings, then strikes it through or
 * clears it. Alone in the row, with no store to buy from, it is the white button and says what it
 * does: "Suivi", "Suivre". Beside a store, the bell on white while it alerts and slashed on glass
 * once silent.
 */
@Composable
private fun Bell(isAlerted: Boolean, isAlone: Boolean, rings: Int, onClick: () -> Unit) {
    val label = if (isAlerted) L("Ne plus être prévenu") else L("Être prévenu de la sortie")
    ActionButton(
        onClick = onClick,
        fill = if (isAlone || isAlerted) ActionFill.WHITE else ActionFill.GLASS,
        shape = if (isAlone) ActionShape.CAPSULE else ActionShape.CIRCLE,
        height = ButtonHeight,
        isRaised = isAlone,
        contentDescription = label,
    ) {
        Icon(Symbol(if (isAlerted) "bell" else "bell.slash"), if (isAlone) null else label, Modifier.size(20.dp).iconGesture(IconGesture.SWING, rings), tint = LocalContentColor.current)
        if (isAlone) Text(if (isAlerted) L("Suivi") else L("Suivre"), style = actionLabelStyle(ButtonHeight), color = LocalContentColor.current, maxLines = 1)
    }
}

/**
 * A round glass button that waits for its action, a spinner in its place meanwhile; first in the
 * row, white with its label beside its icon. A slashed symbol loses its slash for a frame on the
 * tap, so the tap draws it again.
 */
@Composable
private fun AsyncRoundButton(
    title: String,
    symbol: String,
    isPrimary: Boolean = false,
    enabled: Boolean = true,
    /** Asked before the action, which cannot be undone from the page; null acts at once. */
    confirmation: String? = null,
    action: suspend () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var inProgress by remember { mutableStateOf(false) }
    var confirms by remember { mutableStateOf(false) }
    var redraws by remember { mutableStateOf(false) }
    val shown = if (redraws && symbol.endsWith(".slash")) symbol.removeSuffix(".slash") else symbol
    fun run() {
        redraws = true
        inProgress = true
        scope.launch {
            delay(40)
            redraws = false
        }
        scope.launch {
            action()
            inProgress = false
        }
    }
    ActionButton(
        onClick = { if (!inProgress) { if (confirmation != null) confirms = true else run() } },
        fill = if (isPrimary) ActionFill.WHITE else ActionFill.GLASS,
        shape = if (isPrimary) ActionShape.CAPSULE else ActionShape.CIRCLE,
        height = ButtonHeight,
        isRaised = isPrimary,
        enabled = enabled,
        contentDescription = title,
    ) {
        if (inProgress) {
            CircularProgressIndicator(Modifier.size(18.dp), color = LocalContentColor.current, strokeWidth = 2.dp)
        } else {
            Icon(Symbol(shown), if (isPrimary) null else title, Modifier.size(20.dp), tint = LocalContentColor.current)
        }
        if (isPrimary) Text(title, style = actionLabelStyle(ButtonHeight), color = LocalContentColor.current, maxLines = 1)
    }
    if (confirms && confirmation != null) {
        ConfirmationSheet(confirmation, listOf(ConfirmationChoice(title, destructive = true) { run() })) { confirms = false }
    }
}

@Preview(showBackground = true)
@Composable
private fun UnownedBookPageAnnouncedPreview() = PreviewSurface {
    UnownedBookPage(
        DebugFixtures.reading[2].copy(title = "Frieren 16"),
        releaseDate = DebugFixtures.announcedVolume.date,
        store = UnownedBookStore("https://www.amazon.fr", isAudible = false),
        isAlerted = true,
        onToggleBell = {},
        isAdded = false,
        sagaName = "Frieren",
    )
}

@Preview(showBackground = true)
@Composable
private fun UnownedBookPageAwaitedPreview() = PreviewSurface {
    UnownedBookPage(
        DebugFixtures.discoverAwaited[0].cover,
        releaseDate = DebugFixtures.discoverAwaited[0].date,
        store = UnownedBookStore("https://www.audible.fr", isAudible = true),
        isAlerted = true,
        onToggleBell = {},
        isDescribing = true,
        bellConfirmation = BellConfirmation(L("Ne plus suivre ce livre ?"), L("Vous ne serez plus prévenu de sa sortie."), L("Ne plus suivre")),
        recommendedBy = "Léa",
    )
}
