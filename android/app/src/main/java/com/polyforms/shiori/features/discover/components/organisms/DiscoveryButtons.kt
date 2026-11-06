package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.Discovery
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.HeroProminentButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** What the reader does with a discovery. */
sealed interface DiscoveryChoice {
    data object Add : DiscoveryChoice
    data class Await(val format: ReleaseFormat) : DiscoveryChoice
    data object AlreadyRead : DiscoveryChoice
    data object Wish : DiscoveryChoice
    data object UndoAlreadyRead : DiscoveryChoice
    data object NotInterested : DiscoveryChoice
    data object Reconsider : DiscoveryChoice
}

/** What a discovery's buttons show once the reader chose. */
enum class DiscoveryMark { ADDED, READ, NOT_INTERESTED }

enum class DiscoveryButton { ADD, EYE }

/** The marks and spinners of every discovery on screen, kept across pages that show the same one. */
class DiscoveryChoices {
    val marks = mutableStateMapOf<String, DiscoveryMark>()
    val working = mutableStateMapOf<String, DiscoveryButton>()

    fun <Item : Discovery> choose(
        scope: kotlinx.coroutines.CoroutineScope,
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
            if (accepted) {
                if (mark != null) marks[item.id] = mark else marks.remove(item.id)
            }
        }
    }
}

/** The entries of a discovery's add menu: to read, read, wishlist, await an edition. */
fun discoveryAddEntries(item: Discovery, onChoose: (DiscoveryChoice, DiscoveryMark) -> Unit): List<MenuEntry> = buildList {
    add(MenuEntry.Item(L("À lire"), "bookmark.fill") { onChoose(DiscoveryChoice.Add, DiscoveryMark.ADDED) })
    add(MenuEntry.Item(L("Déjà lu"), "checkmark") { onChoose(DiscoveryChoice.AlreadyRead, DiscoveryMark.READ) })
    add(MenuEntry.Divider)
    add(MenuEntry.Item(L("Liste d'envies"), "bookmark") { onChoose(DiscoveryChoice.Wish, DiscoveryMark.ADDED) })
    if (item.awaitableFormats.isNotEmpty()) {
        add(MenuEntry.Divider)
        item.awaitableFormats.forEach { format ->
            add(
                MenuEntry.Item(format.awaitLabel, if (format == ReleaseFormat.AUDIOBOOK) "headphones" else "character.book.closed") {
                    onChoose(DiscoveryChoice.Await(format), DiscoveryMark.ADDED)
                },
            )
        }
    }
}

private val turnedDownRed = Color(0.78f, 0.2f, 0.2f)

/** A discovery's add menu and its eye: not interested, already read, or undo either. */
@Composable
fun <Item : Discovery> RowScope.DiscoveryButtons(
    item: Item,
    choices: DiscoveryChoices,
    onChoice: suspend (Item, DiscoveryChoice) -> Boolean,
    addsInFull: Boolean = false,
) {
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val mark = choices.marks[item.id]
    val working = choices.working[item.id]
    val addIsOff = working != null || mark == DiscoveryMark.READ || mark == DiscoveryMark.NOT_INTERESTED
    fun choose(choice: DiscoveryChoice, button: DiscoveryButton, leaving: DiscoveryMark?) {
        haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
        choices.choose(scope, choice, item, button, leaving, onChoice)
    }
    var addMenu by remember { mutableStateOf(false) }
    var eyeMenu by remember { mutableStateOf(false) }
    val addEntries = discoveryAddEntries(item) { choice, leaving -> choose(choice, DiscoveryButton.ADD, leaving) }
    val addTitle = if (mark == DiscoveryMark.ADDED) L("Ajouté") else L("Ajouter")
    val addSymbol = if (mark == DiscoveryMark.ADDED) "checkmark" else "plus"

    if (addsInFull) {
        Box(Modifier.weight(1f).alpha(if (addIsOff) 0.45f else 1f)) {
            HeroProminentButton({ if (!addIsOff) addMenu = true }) {
                WorkingLabel(working == DiscoveryButton.ADD, Color.Black) {
                    Icon(Symbol(addSymbol), null, Modifier.size(18.dp), tint = Color.Black)
                    Spacer(Modifier.width(6.dp))
                    Text(addTitle, style = Shiori.type.headline, color = Color.Black)
                }
            }
            MenuEntries(addEntries, addMenu) { addMenu = false }
        }
    } else {
        Box {
            RoundGlass(addTitle, enabled = !addIsOff, onClick = { addMenu = true }) {
                WorkingLabel(working == DiscoveryButton.ADD, Color.White) { Icon(Symbol(addSymbol), addTitle, Modifier.size(20.dp), tint = Color.White) }
            }
            MenuEntries(addEntries, addMenu) { addMenu = false }
        }
    }
    when (mark) {
        DiscoveryMark.NOT_INTERESTED -> RoundGlass(L("Écarté"), tint = turnedDownRed, enabled = working == null, onClick = { choose(DiscoveryChoice.Reconsider, DiscoveryButton.EYE, null) }) {
            WorkingLabel(working == DiscoveryButton.EYE, Color.White) { Icon(Symbol("hand.thumbsdown.fill"), L("Écarté"), Modifier.size(20.dp), tint = Color.White) }
        }
        DiscoveryMark.READ -> RoundGlass(L("Déjà lu"), tint = Color.White, enabled = working == null, onClick = { choose(DiscoveryChoice.UndoAlreadyRead, DiscoveryButton.EYE, null) }) {
            WorkingLabel(working == DiscoveryButton.EYE, Color.Black) { Icon(Symbol("checkmark"), L("Déjà lu"), Modifier.size(20.dp), tint = Color.Black) }
        }
        else -> Box {
            RoundGlass(L("Pas intéressé"), enabled = working == null && mark != DiscoveryMark.ADDED, onClick = { eyeMenu = true }) {
                WorkingLabel(working == DiscoveryButton.EYE, Color.White) { Icon(Symbol("eye.slash"), L("Pas intéressé"), Modifier.size(20.dp), tint = Color.White) }
            }
            MenuEntries(
                listOf(
                    MenuEntry.Item(L("Pas intéressé"), "hand.thumbsdown", destructive = true) { choose(DiscoveryChoice.NotInterested, DiscoveryButton.EYE, DiscoveryMark.NOT_INTERESTED) },
                    MenuEntry.Item(L("Déjà lu"), "checkmark.circle") { choose(DiscoveryChoice.AlreadyRead, DiscoveryButton.EYE, DiscoveryMark.READ) },
                ),
                eyeMenu,
            ) { eyeMenu = false }
        }
    }
}

/** A round glass button of a hero, 52 points across. */
@Composable
fun RoundGlass(title: String, tint: Color? = null, enabled: Boolean = true, onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        Modifier.size(52.dp).clip(CircleShape).heroGlass(tint).alpha(if (enabled) 1f else 0.45f)
            .plainClickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun WorkingLabel(isWorking: Boolean, color: Color, content: @Composable () -> Unit) {
    Box(contentAlignment = Alignment.Center) {
        Box(Modifier.alpha(if (isWorking) 0f else 1f)) { androidx.compose.foundation.layout.Row(verticalAlignment = Alignment.CenterVertically) { content() } }
        if (isWorking) CircularProgressIndicator(Modifier.size(20.dp), color = color, strokeWidth = 2.dp)
    }
}


/** Glass over a dark hero: a light veil with a white rim, or a solid tint. */
fun Modifier.heroGlass(tint: Color? = null, shape: androidx.compose.ui.graphics.Shape = CircleShape): Modifier =
    if (tint != null) {
        background(tint.copy(alpha = 0.92f), shape)
    } else {
        background(Color.White.copy(alpha = 0.16f), shape).border(0.5.dp, Color.White.copy(alpha = 0.28f), shape)
    }
