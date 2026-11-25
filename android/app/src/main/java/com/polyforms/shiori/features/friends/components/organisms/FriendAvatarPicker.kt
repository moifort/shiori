package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.animation.core.Animatable
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarHero
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.molecules.ConfettiBurst
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.delay

/** A friend of the row: who they are and what they wear. */
data class FriendAvatarItem(val id: String, val name: String, val avatar: AccountAvatar)

private val AvatarSize = 62.dp

/**
 * The friends as a row of avatars, the way the page is narrowed: nobody picked shows every friend,
 * each avatar tapped picks that friend, tapped again lets them go. Once one is picked, the picked
 * ones wear a white ring and the others fade, so the page says at a glance whose books it shows.
 *
 * A friend an invitation just joined arrives with a welcome: their avatar grows into its place,
 * ringed in white, in a burst of confetti.
 *
 * An avatar held offers "Retirer", which asks before stopping the sharing.
 */
@Composable
fun FriendAvatarPicker(
    items: List<FriendAvatarItem>,
    selected: List<String>,
    modifier: Modifier = Modifier,
    welcomed: String? = null,
    /** A friend removed, once the reader confirmed. Null offers no menu. */
    onRemove: ((String) -> Unit)? = null,
    onToggle: (String) -> Unit,
) {
    val list = rememberLazyListState()
    LaunchedEffect(welcomed) {
        val index = items.indexOfFirst { it.id == welcomed }
        if (index >= 0) list.animateScrollToItem(index, -120)
    }
    LazyRow(
        modifier,
        state = list,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        itemsIndexed(items, key = { _, item -> item.id }) { _, item ->
            Box(Modifier.zIndex(if (item.id == welcomed) 1f else 0f)) {
                FriendAvatar(item, selected, item.id == welcomed, onRemove, onToggle)
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FriendAvatar(
    item: FriendAvatarItem,
    selected: List<String>,
    isWelcomed: Boolean,
    onRemove: ((String) -> Unit)?,
    onToggle: (String) -> Unit,
) {
    val isPicked = item.id in selected
    val isFaded = selected.isNotEmpty() && !isPicked
    val fade by animateFloatAsState(if (isFaded) 0.4f else 1f, tween(300), label = "fade")
    val ring by animateFloatAsState(if (isPicked) 2f else 0f, tween(300), label = "ring")
    var menu by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val colors = Shiori.colors
    Box {
        Column(
            Modifier
                .width(AvatarSize + 8.dp)
                .combinedClickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = { onToggle(item.id) },
                    onLongClick = if (onRemove != null) {
                        {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            menu = true
                        }
                    } else {
                        null
                    },
                )
                .semantics(mergeDescendants = true) {
                    contentDescription = item.name
                    this.selected = isPicked
                },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.welcome(isWelcomed), contentAlignment = Alignment.Center) {
                if (isWelcomed) ConfettiBurst(Modifier.requiredSize(420.dp))
                Box(Modifier.border(ring.dp, Color.White, CircleShape).padding(4.dp)) {
                    AccountAvatarView(item.avatar, item.name, AvatarSize, Modifier.graphicsLayer { alpha = fade })
                }
                if (isWelcomed) Box(Modifier.requiredSize(AvatarSize + 8.dp).border(3.dp, Color.White, CircleShape))
            }
            Text(
                item.name,
                style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
                color = if (isFaded) colors.secondaryLabel else colors.label,
                maxLines = 1,
                textAlign = TextAlign.Center,
            )
        }
        MenuEntries(listOf(MenuEntry.Item(L("Retirer"), "person.badge.minus", destructive = true) { removing = true }), menu) { menu = false }
    }
    if (removing) {
        ConfirmationSheet(
            L("Retirer %@ de vos amis ?", item.name),
            listOf(ConfirmationChoice(L("Retirer"), destructive = true) { onRemove?.invoke(item.id) }),
            message = L("Vos bibliothèques ne seront plus partagées."),
        ) { removing = false }
    }
}

/**
 * A friend's arrival: the avatar grows in past its size and settles, with a soft glow; the ring
 * and the confetti are drawn by the avatar's box.
 */
@Composable
private fun Modifier.welcome(isOn: Boolean): Modifier {
    if (!isOn) return this
    val scale = remember { Animatable(0.3f) }
    LaunchedEffect(Unit) {
        scale.animateTo(1.18f, spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow))
        delay(420)
        scale.animateTo(1f, tween(500))
    }
    return this
        .scale(scale.value)
        .shadow(16.dp, CircleShape, clip = false, ambientColor = Color.Yellow.copy(alpha = 0.45f), spotColor = Color.Yellow.copy(alpha = 0.45f))
}

private val previewItems = listOf(
    FriendAvatarItem("marc", "Marc", AccountAvatar.Hero(AvatarHero.KVOTHE)),
    FriendAvatarItem("sophie", "Sophie", AccountAvatar.Hero(AvatarHero.ALICE)),
    FriendAvatarItem("lea", "Léa", AccountAvatar.Hero(AvatarHero.KATNISS)),
    FriendAvatarItem("camille", "Camille", AccountAvatar.Initials),
)

@Preview(showBackground = true)
@Composable
private fun FriendAvatarPickerPreview() = PreviewSurface(dark = true) {
    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        FriendAvatarPicker(previewItems, emptyList()) {}
        FriendAvatarPicker(previewItems, listOf("marc", "sophie")) {}
        FriendAvatarPicker(previewItems, emptyList(), welcomed = "camille") {}
    }
}
