package com.polyforms.shiori.shared.components.organisms

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.account.AvatarHero
import com.polyforms.shiori.shared.account.squarePhoto
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** The faces a reader may take: a photo, initials, a colour, a hero of the classics. */
@Composable
fun AvatarPickerSheet(current: AccountAvatar, firstName: String?, onDismiss: () -> Unit, onPick: (AccountAvatar) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var loadingPhoto by remember { mutableStateOf(false) }
    val isPhoto = current is AccountAvatar.Photo || current is AccountAvatar.PickedPhoto
    ShioriSheet(onDismiss) { dismiss ->
        fun pick(avatar: AccountAvatar) {
            onPick(avatar)
            dismiss()
        }
        val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
            uri ?: return@rememberLauncherForActivityResult
            loadingPhoto = true
            scope.launch {
                val square = withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)?.use { it.readBytes() }?.let(::squarePhoto) }
                loadingPhoto = false
                square?.let { pick(AccountAvatar.PickedPhoto(it)) }
            }
        }
        SheetBar(L("Avatar"), leading = { ToolbarIconButton(L("Fermer"), "xmark") { dismiss() } })
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
            Shelf(L("Vous"), buildList {
                add(Triple(L("Photo"), isPhoto, @Composable {
                    if (isPhoto) {
                        AccountAvatarView(current, firstName, 72.dp)
                    } else {
                        Box(Modifier.size(72.dp).background(Shiori.colors.tertiaryFill, CircleShape), contentAlignment = Alignment.Center) {
                            Icon(Symbol(if (loadingPhoto) "hourglass" else "photo.on.rectangle"), null, Modifier.size(26.dp), tint = Shiori.colors.secondaryLabel)
                        }
                    }
                }) to { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
                add(Triple(L("Initiales"), current == AccountAvatar.Initials, @Composable { AccountAvatarView(AccountAvatar.Initials, firstName, 72.dp) }) to { pick(AccountAvatar.Initials) })
                AvatarColor.entries.forEach { color ->
                    val avatar = AccountAvatar.Tinted(color)
                    add(Triple(color.displayName, current == avatar, @Composable { AccountAvatarView(avatar, firstName, 72.dp) }) to { pick(avatar) })
                }
            })
            AvatarHero.Shelf.entries.forEach { row ->
                Shelf(row.title, row.heroes.map { hero ->
                    val avatar = AccountAvatar.Hero(hero)
                    Triple(hero.displayName, current == avatar, @Composable { AccountAvatarView(avatar, null, 72.dp) }) to { pick(avatar) }
                })
            }
        }
    }
}

@Composable
private fun Shelf(title: String, choices: List<Pair<Triple<String, Boolean, @Composable () -> Unit>, () -> Unit>>) {
    val colors = Shiori.colors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, style = Shiori.type.headline, color = colors.label)
        choices.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (choice, action) ->
                    val (label, selected, face) = choice
                    Column(Modifier.weight(1f).plainClickable(onClick = action), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(Modifier.border(2.5.dp, if (selected) colors.label else Color.Transparent, CircleShape).padding(3.dp)) { face() }
                        Text(label, style = Shiori.type.caption, color = if (selected) colors.label else colors.secondaryLabel, textAlign = TextAlign.Center, maxLines = 2)
                    }
                }
                repeat(4 - row.size) { Box(Modifier.weight(1f)) }
            }
        }
    }
}
