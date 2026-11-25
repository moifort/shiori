package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.AnimatedContent
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionShape
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.actionLabelStyle
import com.polyforms.shiori.shared.components.styles.iconGesture
import com.polyforms.shiori.shared.components.styles.refusalShake
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry

/**
 * What the "+ Ajouter" of a book the reader does not hold made of it, said in its place by a
 * glass capsule: one action at a time — on the pile, read already, on the wish list, an edition
 * awaited — or the book held already.
 */
sealed interface TakenState {
    data class ToRead(val isAudio: Boolean) : TakenState
    data class Read(val isAudio: Boolean) : TakenState
    data object Wished : TakenState
    data class Awaited(val format: ReleaseFormat) : TakenState

    /** In the library already, in any format: nothing left to take. */
    data object Owned : TakenState

    val title: String
        get() = when (this) {
            is ToRead -> if (isAudio) L("À écouter") else L("À lire")
            is Read -> if (isAudio) L("Écouté") else L("Lu")
            Wished -> L("Envie")
            is Awaited -> if (format == ReleaseFormat.AUDIOBOOK) L("Audio") else L("Traduction")
            Owned -> L("Ajouté")
        }

    /** The icon of the menu's entry that was chosen. */
    val symbol: String
        get() = when (this) {
            is ToRead -> if (isAudio) "headphones" else "bookmark.fill"
            is Read, Owned -> "checkmark"
            Wished -> "bookmark"
            is Awaited -> format.awaitedSymbol
        }

    /** What the capsule's icon does as it appears. */
    val gesture: IconGesture
        get() = when (this) {
            is ToRead, Wished -> IconGesture.SLIP
            is Read, Owned -> IconGesture.HOP
            is Awaited -> IconGesture.SWEEP
        }

    /** Asked before the choice is taken back: what the tap will undo. */
    val undoQuestion: String
        get() = when (this) {
            Wished -> L("Retirer de la liste d'envies ?")
            is ToRead -> if (isAudio) L("Retirer de la pile à écouter ?") else L("Retirer de la pile à lire ?")
            is Read -> if (isAudio) L("Retirer des livres écoutés ?") else L("Retirer des livres lus ?")
            is Awaited -> if (format == ReleaseFormat.AUDIOBOOK) L("Ne plus guetter l'audio ?") else L("Ne plus guetter la traduction ?")
            Owned -> ""
        }

    /** The dialog's red button, as short as it can be. */
    val undoAction: String get() = if (this is Awaited) L("Ne plus guetter") else L("Retirer")

    /** Said by TalkBack. */
    val accessibilityTitle: String
        get() = when (this) {
            is ToRead -> if (isAudio) L("À écouter") else L("À lire")
            is Read -> if (isAudio) L("Écouté") else L("Lu")
            Wished -> L("Dans vos envies")
            is Awaited -> if (format == ReleaseFormat.AUDIOBOOK) L("Audio guetté") else L("Traduction guettée")
            Owned -> L("Déjà dans votre bibliothèque")
        }
}

/** A large card's foot (28) or a book page's hero (50). */
enum class AddMenuSize(val height: Dp) { CARD(28.dp), PAGE(50.dp) }

/**
 * "+ Ajouter", the one button of a book the reader does not hold, wherever it may be taken. White,
 * it opens the menu of everything the book can become, and the reader picks one thing. Once the
 * choice went through, it turns to glass and says what was done, with the icon of the entry
 * chosen; a second tap asks first, then undoes it and gives "+ Ajouter" back.
 *
 * Turned down (the closed eye beside it), the button greys but stays live: a tap takes the
 * refusal back rather than opening the menu. While the server answers, a spinner holds its place;
 * refused, it shakes.
 */
@Composable
fun AddMenuButton(
    entries: List<MenuEntry>,
    modifier: Modifier = Modifier,
    size: AddMenuSize = AddMenuSize.CARD,
    isRound: Boolean = false,
    done: TakenState? = null,
    isDisabled: Boolean = false,
    isTurnedDown: Boolean = false,
    onReconsider: () -> Unit = {},
    isWorking: Boolean = false,
    refusals: Int = 0,
    onUndo: (() -> Unit)? = null,
) {
    var expanded by remember { mutableStateOf(false) }
    var confirmsUndo by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val first = remember { mutableStateOf(true) }
    LaunchedEffect(done) {
        if (first.value) first.value = false
        else haptics.performHapticFeedback(if (done != null) HapticFeedbackType.Confirm else HapticFeedbackType.ContextClick)
    }
    val height = size.height
    Box(modifier.refusalShake(refusals)) {
        AnimatedContent(
            done,
            transitionSpec = { (scaleIn(initialScale = 0.6f, transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0.5f)) + fadeIn()) togetherWith fadeOut() },
            label = "taken",
        ) { taken ->
            if (taken != null) {
                ActionButton(
                    onClick = { confirmsUndo = true },
                    fill = ActionFill.GLASS,
                    height = height,
                    enabled = !isWorking,
                    inert = onUndo == null,
                    contentDescription = taken.accessibilityTitle,
                ) {
                    Working(isWorking) {
                        var shown by remember { mutableIntStateOf(0) }
                        LaunchedEffect(Unit) { shown += 1 }
                        Icon(Symbol(taken.symbol), null, Modifier.size(if (size == AddMenuSize.CARD) 13.dp else 20.dp).iconGesture(taken.gesture, shown), tint = LocalContentColor.current)
                        Text(taken.title, style = actionLabelStyle(height), color = LocalContentColor.current, maxLines = 1)
                    }
                }
            } else {
                ActionButton(
                    onClick = { if (isTurnedDown) onReconsider() else expanded = true },
                    modifier = Modifier.graphicsLayer { alpha = if (isTurnedDown || isDisabled) 0.45f else 1f },
                    fill = if (isRound) ActionFill.GLASS else ActionFill.WHITE,
                    shape = if (isRound) ActionShape.CIRCLE else ActionShape.CAPSULE,
                    height = height,
                    isRaised = !isRound && size == AddMenuSize.PAGE,
                    enabled = !isWorking && (isTurnedDown || !isDisabled),
                    contentDescription = L("Ajouter"),
                ) {
                    Working(isWorking) {
                        Icon(Symbol("plus"), null, Modifier.size(if (size == AddMenuSize.CARD) 13.dp else 20.dp), tint = LocalContentColor.current)
                        if (!isRound) Text(L("Ajouter"), style = actionLabelStyle(height), color = LocalContentColor.current, maxLines = 1)
                    }
                }
            }
        }
        MenuEntries(entries, expanded) { expanded = false }
    }
    if (confirmsUndo && done != null) {
        ConfirmationSheet(done.undoQuestion, listOf(ConfirmationChoice(done.undoAction, destructive = true) { onUndo?.invoke() })) { confirmsUndo = false }
    }
}

/** The label, or a spinner holding its place while the server answers. */
@Composable
private fun Working(isWorking: Boolean, label: @Composable () -> Unit) {
    Box(contentAlignment = Alignment.Center) {
        androidx.compose.foundation.layout.Row(
            Modifier.graphicsLayer { alpha = if (isWorking) 0f else 1f },
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) { label() }
        if (isWorking) CircularProgressIndicator(Modifier.size(16.dp), color = LocalContentColor.current, strokeWidth = 2.dp)
    }
}

/**
 * The barred eye beside "+ Ajouter": one tap turns the book down, its cover going black and
 * white, and the eye opens on white; a second tap on the open eye takes the refusal back.
 */
@Composable
fun NotInterestedToggle(isOn: Boolean, modifier: Modifier = Modifier, size: AddMenuSize = AddMenuSize.CARD, onToggle: suspend (Boolean) -> Unit) {
    ActionToggle(
        isOn = isOn,
        symbol = "eye",
        offSymbol = "eye.slash",
        turnOnLabel = L("Pas intéressé"),
        turnOffLabel = L("Ça m'intéresse finalement"),
        modifier = modifier,
        size = size.height,
        gesture = IconGesture.BLINK,
        onToggle = onToggle,
    )
}

@Preview(showBackground = true)
@Composable
private fun AddMenuButtonPreview() = PreviewSurface(dark = true) {
    val entries = listOf(MenuEntry.Item(L("À lire"), "bookmark") {})
    Column(Modifier.background(Color.Black).padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        AddMenuButton(entries)
        AddMenuButton(entries, done = TakenState.Wished, onUndo = {})
        AddMenuButton(entries, size = AddMenuSize.PAGE)
        AddMenuButton(entries, size = AddMenuSize.PAGE, done = TakenState.ToRead(isAudio = true), onUndo = {})
        AddMenuButton(entries, size = AddMenuSize.PAGE, done = TakenState.Awaited(ReleaseFormat.BOOK), onUndo = {})
        AddMenuButton(entries, size = AddMenuSize.PAGE, isTurnedDown = true)
        AddMenuButton(emptyList(), done = TakenState.Owned)
        NotInterestedToggle(false) {}
    }
}
