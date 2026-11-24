package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.Discovery
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.molecules.AddMenuButton
import com.polyforms.shiori.shared.components.molecules.AddMenuSize
import com.polyforms.shiori.shared.components.molecules.NotInterestedToggle
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Optional

/** What the server says the reader made of it already: an edition awaited. */
val Discovery.serverMark: DiscoveryMark? get() = if (awaitedEditionId == null) null else DiscoveryMark.Awaited(format)

/** The formats it may be taken in: the book and its recording, whatever the format it is listed in. */
val Discovery.takenFormats: List<BookFormat> get() = listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK)

/**
 * The book as it goes onto the shelf in the format chosen: a recording holds no medium, a printed
 * book the paper one unless it says another.
 */
fun BookDraft.taken(format: BookFormat, status: ReadingStatus): BookDraft = copy(
    format = format,
    media = if (format == BookFormat.AUDIOBOOK) emptyList() else media.ifEmpty { listOf(BookMedium.PRINT) },
    status = status,
)

/**
 * What the reader decides about a discovery from its "+ Ajouter" and its closed eye: one action at
 * a time, which the same button takes back.
 */
sealed interface DiscoveryChoice {
    /** On the pile, in the format chosen. */
    data class Add(val format: BookFormat) : DiscoveryChoice

    /** Among the books read, in the format chosen. */
    data class AlreadyRead(val format: BookFormat) : DiscoveryChoice

    /** Onto the reader's wishlist. */
    data object Wish : DiscoveryChoice

    /** The "Envie" capsule pressed: off the wishlist. */
    data object Unwish : DiscoveryChoice

    /** The "Lu" capsule pressed: the book leaves the shelf. */
    data object UndoAlreadyRead : DiscoveryChoice

    /** The "À lire" capsule pressed: the book leaves the pile. */
    data object UndoAdd : DiscoveryChoice
    data class Await(val format: ReleaseFormat) : DiscoveryChoice

    /** An edition awaited given up, from its capsule. */
    data class Unawait(val format: ReleaseFormat) : DiscoveryChoice
    data object NotInterested : DiscoveryChoice

    /** The eye pressed again, or the greyed "Ajouter": the book interests the reader after all. */
    data object Reconsider : DiscoveryChoice
}

/** What a discovery's buttons say of the reader's choice. */
sealed interface DiscoveryMark {
    data class Added(val format: BookFormat) : DiscoveryMark
    data class Read(val format: BookFormat) : DiscoveryMark
    data object Wished : DiscoveryMark
    data class Awaited(val format: ReleaseFormat) : DiscoveryMark

    /** Turned down from the eye: the book goes black and white. */
    data object NotInterested : DiscoveryMark

    /** Said in the "+ Ajouter"'s capsule. */
    val taken: TakenState?
        get() = when (this) {
            is Added -> TakenState.ToRead(isAudio = format == BookFormat.AUDIOBOOK)
            is Read -> TakenState.Read(isAudio = format == BookFormat.AUDIOBOOK)
            Wished -> TakenState.Wished
            is Awaited -> TakenState.Awaited(format)
            NotInterested -> null
        }

    /** What a tap on the capsule sends: the choice taken back. */
    val undo: DiscoveryChoice?
        get() = when (this) {
            is Added -> DiscoveryChoice.UndoAdd
            is Read -> DiscoveryChoice.UndoAlreadyRead
            Wished -> DiscoveryChoice.Unwish
            is Awaited -> DiscoveryChoice.Unawait(format)
            NotInterested -> null
        }
}

/** The two buttons of a discovery that ask the server. */
enum class DiscoveryButton { ADD, EYE }

/**
 * What the reader decided about each discovery, held apart from the views so the home's hero and
 * the page it opens say the same thing.
 */
class DiscoveryChoices {
    /** The choices made here; a null value is one taken back, over what the server listed. */
    private val marks = mutableStateMapOf<String, Optional<DiscoveryMark>>()

    /** The button whose choice the server is answering, with its spinner. */
    val working = mutableStateMapOf<String, DiscoveryButton>()

    /** Bumped each time the server refused a choice: the buttons shake. */
    val refusals = mutableStateMapOf<String, Int>()

    /** What the reader made of the discovery: here, else as the server listed it. */
    fun mark(item: Discovery): DiscoveryMark? {
        val local = marks[item.id] ?: return item.serverMark
        return local.orElse(null)
    }

    /** Turned down here: drawn black and white. */
    fun isTurnedDown(item: Discovery): Boolean = mark(item) == DiscoveryMark.NotInterested

    /**
     * Sends a choice and sets the mark it leaves once the server took it, and not before the menu
     * has closed: drawn while it folds back into the button, the mark went unseen.
     */
    fun <Item : Discovery> choose(
        scope: CoroutineScope,
        choice: DiscoveryChoice,
        item: Item,
        button: DiscoveryButton,
        mark: DiscoveryMark?,
        ask: suspend (Item, DiscoveryChoice) -> Boolean,
    ) {
        if (working[item.id] != null) return
        working[item.id] = button
        scope.launch {
            val folded = async { delay(450) }
            val accepted = ask(item, choice)
            folded.await()
            working.remove(item.id)
            if (accepted) marks[item.id] = Optional.ofNullable(mark) else refusals[item.id] = (refusals[item.id] ?: 0) + 1
        }
    }
}

/**
 * What a discovery's "+ Ajouter" offers, on its page and on the home's hero — the menu a friend's
 * book and a large card offer too: on the pile or read, in print and as a recording, then the wish
 * list, then each edition still to await. Each choice names the mark it leaves on the button.
 */
fun discoveryAddEntries(item: Discovery, onChoose: (DiscoveryChoice, DiscoveryMark) -> Unit): List<MenuEntry> = buildList {
    item.takenFormats.forEachIndexed { index, format ->
        if (index > 0) add(MenuEntry.Divider)
        val audio = format == BookFormat.AUDIOBOOK
        add(MenuEntry.Item(if (audio) L("À écouter") else L("À lire"), "bookmark.fill") { onChoose(DiscoveryChoice.Add(format), DiscoveryMark.Added(format)) })
        add(MenuEntry.Item(if (audio) L("Déjà écouté") else L("Déjà lu"), "checkmark") { onChoose(DiscoveryChoice.AlreadyRead(format), DiscoveryMark.Read(format)) })
    }
    add(MenuEntry.Divider)
    add(MenuEntry.Item(L("Ajouter à la liste d'envies"), "bookmark") { onChoose(DiscoveryChoice.Wish, DiscoveryMark.Wished) })
    if (item.awaitableFormats.isNotEmpty()) {
        add(MenuEntry.Divider)
        item.awaitableFormats.forEach { format ->
            add(
                MenuEntry.Item(format.awaitLabel, if (format == ReleaseFormat.AUDIOBOOK) "headphones" else "binoculars") {
                    onChoose(DiscoveryChoice.Await(format), DiscoveryMark.Awaited(format))
                },
            )
        }
    }
}

/**
 * A discovery's buttons, side by side in whatever row holds them: on its page the white
 * "+ Ajouter" and the closed eye; on the home's hero the round "+" and the eye. The "+" opens every
 * way to take the book — on the pile or read, in print or as a recording, on the wish list, an
 * edition awaited — and says the one chosen. The eye turns the book down in one tap, black and
 * white, and a second tap, or one on the greyed "+", takes it back.
 */
@Composable
fun <Item : Discovery> RowScope.DiscoveryButtons(
    item: Item,
    choices: DiscoveryChoices,
    onChoice: suspend (Item, DiscoveryChoice) -> Boolean,
    addsInFull: Boolean = false,
) {
    val scope = rememberCoroutineScope()
    val mark = choices.mark(item)
    val working = choices.working[item.id]
    val isTurnedDown = mark == DiscoveryMark.NotInterested
    fun choose(choice: DiscoveryChoice, button: DiscoveryButton, leaving: DiscoveryMark?) {
        choices.choose(scope, choice, item, button, leaving, onChoice)
    }
    AddMenuButton(
        entries = discoveryAddEntries(item) { choice, leaving -> choose(choice, DiscoveryButton.ADD, leaving) },
        size = AddMenuSize.PAGE,
        isRound = !addsInFull,
        done = mark?.taken,
        isTurnedDown = isTurnedDown,
        onReconsider = { choose(DiscoveryChoice.Reconsider, DiscoveryButton.ADD, null) },
        isWorking = working == DiscoveryButton.ADD,
        refusals = choices.refusals[item.id] ?: 0,
        onUndo = { mark?.undo?.let { choose(it, DiscoveryButton.ADD, null) } },
    )
    // Offered while nothing else was chosen: a book taken is not turned down.
    val taken = mark != null && !isTurnedDown
    Box(Modifier.alpha(if (taken) 0.45f else 1f)) {
        NotInterestedToggle(isOn = isTurnedDown, size = AddMenuSize.PAGE) { turnDown ->
            choose(if (turnDown) DiscoveryChoice.NotInterested else DiscoveryChoice.Reconsider, DiscoveryButton.EYE, if (turnDown) DiscoveryMark.NotInterested else null)
        }
        // Disabled while the server answers or once something else was chosen: the taps stop here.
        if (working != null || taken) {
            Box(Modifier.matchParentSize().clickable(remember { MutableInteractionSource() }, null) {})
        }
    }
}

/** A round glass button of a hero, 52 points across: the home hero's "Vu" until its own port. */
@Composable
fun RoundGlass(title: String, tint: Color? = null, enabled: Boolean = true, onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        Modifier.size(52.dp).clip(CircleShape).heroGlass(tint).alpha(if (enabled) 1f else 0.45f)
            .plainClickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** Glass over a dark hero: a light veil with a white rim, or a solid tint. */
fun Modifier.heroGlass(tint: Color? = null, shape: androidx.compose.ui.graphics.Shape = CircleShape): Modifier =
    if (tint != null) {
        background(tint.copy(alpha = 0.92f), shape)
    } else {
        background(Color.White.copy(alpha = 0.16f), shape).border(0.5.dp, Color.White.copy(alpha = 0.28f), shape)
    }

@Preview(showBackground = true)
@Composable
private fun DiscoveryButtonsPreview() = PreviewSurface(dark = true) {
    Column(Modifier.background(Color.Black).padding(16.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        // The home's hero: the round "+" and the eye.
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            DiscoveryButtons(DebugFixtures.discoveries.suggestions[0], remember { DiscoveryChoices() }, { _, _ -> true })
        }
        // The page: "+ Ajouter" in full, then the eye.
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            DiscoveryButtons(DebugFixtures.discoveries.suggestions[0], remember { DiscoveryChoices() }, { _, _ -> true }, addsInFull = true)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RoundGlass("Vu", onClick = {}) { Text("✓") }
        }
    }
}
