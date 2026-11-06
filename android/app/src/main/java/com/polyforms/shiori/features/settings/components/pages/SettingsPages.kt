package com.polyforms.shiori.features.settings.components.pages

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.settings.AlertKind
import com.polyforms.shiori.features.settings.ChangelogEntry
import com.polyforms.shiori.features.settings.NotificationSettings
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.FeedbackKind
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.LabeledInfoRow
import com.polyforms.shiori.shared.components.organisms.AvatarPickerSheet
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.SegmentedControl
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import kotlinx.coroutines.delay

@Composable
private fun SettingsColumn(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) { content() }
}

/** A settings line: a white glyph on a tinted badge, a title and a line under it. */
@Composable
fun SettingsRow(icon: String, title: String, subtitle: String?, tint: Color, divider: Boolean = true, onClick: () -> Unit) {
    val colors = Shiori.colors
    FormRow(divider = divider, onClick = onClick) {
        Box(Modifier.size(28.dp).background(tint, RoundedCornerShape(6.dp)), contentAlignment = Alignment.Center) {
            Icon(Symbol(icon), null, Modifier.size(15.dp), tint = Color.White)
        }
        Column(Modifier.weight(1f).padding(start = 14.dp, top = 6.dp, bottom = 6.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Shiori.type.body, color = colors.label)
            subtitle?.let { Text(it, style = Shiori.type.footnote, color = colors.secondaryLabel) }
        }
        Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
    }
}

enum class SettingsDestination { PROFILE, NOTIFICATIONS, CHANGELOG }

sealed interface SettingsHomeAction {
    data class Open(val destination: SettingsDestination) : SettingsHomeAction
    data object ShowPremium : SettingsHomeAction
    data object ShowFeedback : SettingsHomeAction
    data class OpenSource(val source: ImportSource) : SettingsHomeAction
}

/** The settings: profile, Premium, notifications, the sources, the version, a word to us. */
@Composable
fun SettingsHomePage(profileSubtitle: String?, isPremium: Boolean?, notificationsBlocked: Boolean, appVersion: String, buildNumber: String, onAction: (SettingsHomeAction) -> Unit) {
    val colors = Shiori.colors
    SettingsColumn {
        FormSection {
            SettingsRow("person.crop.circle.fill", L("Profil"), profileSubtitle, colors.blue) { onAction(SettingsHomeAction.Open(SettingsDestination.PROFILE)) }
            SettingsRow(
                "sparkles",
                if (isPremium == true) L("Shiori Premium") else L("Découvrir Premium"),
                when (isPremium) {
                    true -> L("Scans illimités")
                    false -> L("Scannez sans compter")
                    null -> null
                },
                colors.orange,
            ) { onAction(SettingsHomeAction.ShowPremium) }
            SettingsRow(
                if (notificationsBlocked) "bell.slash.fill" else "bell.badge.fill",
                L("Notifications"),
                if (notificationsBlocked) L("Désactivées dans les réglages du téléphone") else L("Prochaine sortie et nouvelle disponibilité"),
                colors.red,
                divider = false,
            ) { onAction(SettingsHomeAction.Open(SettingsDestination.NOTIFICATIONS)) }
        }
        FormSection(L("Sources")) {
            ImportSource.entries.forEachIndexed { index, source ->
                SettingsRow(source.symbol, source.label, source.subtitle, colors.teal, divider = index < ImportSource.entries.lastIndex) { onAction(SettingsHomeAction.OpenSource(source)) }
            }
        }
        FormSection(L("Application")) {
            SettingsRow("doc.text.fill", L("Version et nouveautés"), "v$appVersion ($buildNumber)", colors.indigo) { onAction(SettingsHomeAction.Open(SettingsDestination.CHANGELOG)) }
            SettingsRow("envelope.fill", L("Nous écrire"), L("Signaler un problème ou proposer une idée"), colors.pink, divider = false) { onAction(SettingsHomeAction.ShowFeedback) }
        }
    }
}

sealed interface ProfileSettingsAction {
    data class ChangeAvatar(val avatar: AccountAvatar) : ProfileSettingsAction
    data object SignOut : ProfileSettingsAction
    data object DeleteAccount : ProfileSettingsAction
}

/** The account: the face, the name, the identifier, signing out and deleting it. */
@Composable
fun ProfileSettingsPage(
    firstName: String?,
    avatar: AccountAvatar,
    isSavingAvatar: Boolean,
    displayName: String?,
    shortUid: String,
    isDeletingAccount: Boolean,
    errorMessage: String?,
    onAction: (ProfileSettingsAction) -> Unit,
) {
    val colors = Shiori.colors
    var picking by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var showsUid by remember { mutableStateOf(false) }
    val name = listOfNotNull(displayName, firstName).firstOrNull { it.isNotEmpty() }
    SettingsColumn {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 8.dp).plainClickable(enabled = !isSavingAvatar) { picking = true },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                AccountAvatarView(avatar, firstName, 96.dp, Modifier.alpha(if (isSavingAvatar) 0.5f else 1f))
                if (isSavingAvatar) CircularProgressIndicator()
            }
            Text(L("Modifier"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.accent)
        }
        FormSection(L("Compte")) {
            name?.let { LabeledInfoRow(L("Nom"), it, "person.fill") }
            if (showsUid) {
                LabeledInfoRow(L("Identifiant"), shortUid, "key.fill")
            } else {
                FormRow(divider = false, onClick = { showsUid = true }) {
                    Icon(Symbol("key.fill"), null, Modifier.size(18.dp), tint = colors.accent)
                    Text(L("Afficher l'identifiant"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.padding(start = 12.dp))
                }
            }
        }
        FormSection(footer = errorMessage) {
            FormRow(onClick = { onAction(ProfileSettingsAction.SignOut) }) {
                Icon(Symbol("rectangle.portrait.and.arrow.right"), null, Modifier.size(18.dp), tint = colors.red)
                Text(L("Se déconnecter"), style = Shiori.type.body, color = colors.red, modifier = Modifier.padding(start = 12.dp))
            }
            FormRow(divider = false, onClick = if (isDeletingAccount) null else ({ confirmDelete = true })) {
                if (isDeletingAccount) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Symbol("trash"), null, Modifier.size(18.dp), tint = colors.red)
                    Text(L("Supprimer mon compte"), style = Shiori.type.body, color = colors.red, modifier = Modifier.padding(start = 12.dp))
                }
            }
        }
    }
    if (picking) AvatarPickerSheet(avatar, firstName, { picking = false }) { onAction(ProfileSettingsAction.ChangeAvatar(it)) }
    if (confirmDelete) {
        ConfirmationSheet(
            L("Supprimer définitivement le compte ?"),
            listOf(ConfirmationChoice(L("Supprimer mon compte"), destructive = true) { onAction(ProfileSettingsAction.DeleteAccount) }),
            L("Votre bibliothèque, vos notes et vos séries seront effacées sans possibilité de récupération. Un abonnement Premium éventuel n'est pas résilié et reste à annuler dans Google Play."),
        ) { confirmDelete = false }
    }
}

sealed interface NotificationSettingsAction {
    data class Set(val kind: AlertKind, val enabled: Boolean) : NotificationSettingsAction
    data class SilenceAll(val silenced: Boolean) : NotificationSettingsAction
    data object OpenSystemSettings : NotificationSettingsAction
}

/** The alerts to receive, each switched on or off, and a way to silence them all. */
@Composable
fun NotificationSettingsPage(settings: NotificationSettings?, blocked: Boolean, errorMessage: String?, saving: Boolean, onAction: (NotificationSettingsAction) -> Unit) {
    val colors = Shiori.colors
    Box(Modifier.fillMaxSize()) {
        SettingsColumn {
            if (blocked) {
                FormSection {
                    FormRow {
                        Icon(Symbol("bell.slash.fill"), null, Modifier.size(20.dp), tint = colors.red)
                        Column(Modifier.padding(start = 12.dp, top = 6.dp, bottom = 6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(L("Notifications désactivées"), style = Shiori.type.headline, color = colors.label)
                            Text(L("Shiori n'est pas autorisé à vous prévenir. Activez ses notifications dans les réglages du téléphone pour recevoir ces alertes."), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                        }
                    }
                    FormRow(divider = false, onClick = { onAction(NotificationSettingsAction.OpenSystemSettings) }) {
                        Text(L("Ouvrir les réglages du téléphone"), style = Shiori.type.body, color = colors.accent)
                    }
                }
            }
            if (settings != null) {
                FormSection(L("Me prévenir"), modifier = Modifier.alpha(if (blocked) 0.5f else 1f)) {
                    val kinds = listOf(AlertKind.DIGEST, AlertKind.TRANSLATION, AlertKind.DISCOVERIES)
                    kinds.forEachIndexed { index, kind ->
                        FormRow(divider = index < kinds.lastIndex) {
                            Icon(Symbol(kind.symbol), null, Modifier.size(18.dp), tint = colors.accent)
                            Text(kind.title, style = Shiori.type.body, color = colors.label, modifier = Modifier.weight(1f).padding(start = 12.dp))
                            ShioriSwitch(kind in settings.enabled, { onAction(NotificationSettingsAction.Set(kind, it)) }, enabled = !blocked && !saving)
                        }
                    }
                }
                FormSection(modifier = Modifier.alpha(if (blocked) 0.5f else 1f)) {
                    FormRow(divider = false) {
                        Icon(Symbol("bell.slash"), null, Modifier.size(18.dp), tint = colors.accent)
                        Text(L("Tout désactiver"), style = Shiori.type.body, color = colors.label, modifier = Modifier.weight(1f).padding(start = 12.dp))
                        ShioriSwitch(settings.enabled.isEmpty(), { onAction(NotificationSettingsAction.SilenceAll(it)) }, enabled = !blocked && !saving)
                    }
                }
            }
        }
        if (settings == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (errorMessage != null) {
                    Text(errorMessage, style = Shiori.type.body, color = colors.secondaryLabel, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 40.dp))
                } else {
                    CircularProgressIndicator()
                }
            }
        }
    }
}

/** The versions and what each brought, the coming one first. */
@Composable
fun ChangelogPage(entries: List<ChangelogEntry>, isLoading: Boolean, errorMessage: String?, onRefresh: suspend () -> Unit) {
    val colors = Shiori.colors
    when {
        isLoading && entries.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        errorMessage != null && entries.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            FailureState(L("Notes de version indisponibles"), errorMessage, retry = onRefresh)
        }
        else -> SettingsColumn {
            entries.forEach { entry ->
                Column {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 6.dp)) {
                        Text(entry.version.uppercase(), style = Shiori.type.footnote, color = colors.secondaryLabel, modifier = Modifier.weight(1f))
                        Text(entry.date?.let { DateText.dayMonthShortYear(DateText.local(it)) } ?: L("À venir"), style = Shiori.type.footnote, color = colors.secondaryLabel)
                    }
                    FormSection {
                        entry.notes.forEachIndexed { index, note ->
                            FormRow(divider = index < entry.notes.lastIndex) {
                                Box(Modifier.padding(top = 2.dp).size(5.dp).background(colors.secondaryLabel, RoundedCornerShape(50)))
                                Text(note, style = Shiori.type.callout, color = colors.label, modifier = Modifier.padding(start = 12.dp, top = 8.dp, bottom = 8.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

/** "Nous écrire": a problem or an idea, sent with nothing but the account's id. */
@Composable
fun FeedbackSheet(onDismiss: () -> Unit, onSend: (FeedbackKind, String) -> Unit) {
    var kind by remember { mutableStateOf(FeedbackKind.BUG) }
    var message by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    val colors = Shiori.colors
    ShioriSheet(onDismiss) { dismiss ->
        LaunchedEffect(sent) {
            if (!sent) return@LaunchedEffect
            delay(2000)
            dismiss()
        }
        SheetBar(
            L("Nous écrire"),
            leading = { ToolbarIconButton(if (sent) L("Terminé") else L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                if (!sent) {
                    ToolbarIconButton(L("Envoyer"), "paperplane.fill", prominent = true, enabled = message.isNotBlank()) {
                        onSend(kind, message.trim())
                        sent = true
                    }
                }
            },
        )
        AnimatedContent(sent, label = "feedback") { done ->
            if (done) {
                Column(Modifier.fillMaxWidth().padding(horizontal = 40.dp, vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Icon(Symbol("checkmark.circle.fill"), null, Modifier.size(76.dp), tint = colors.green)
                    Text(L("Message envoyé"), style = Shiori.type.title3.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                    Text(L("Merci, votre message nous aide à améliorer l'application."), style = Shiori.type.subheadline, color = colors.secondaryLabel, textAlign = TextAlign.Center)
                }
            } else {
                Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SegmentedControl(FeedbackKind.entries, kind, { if (it == FeedbackKind.BUG) L("Problème") else L("Suggestion") }, { kind = it }, Modifier.padding(horizontal = 16.dp))
                    FormSection {
                        PlainTextField(
                            message,
                            { message = it },
                            if (kind == FeedbackKind.BUG) L("Décrivez ce que vous faisiez et ce qui s'est passé.") else L("Dites-nous ce qui manque ou ce qui gagnerait à changer."),
                            Modifier.padding(16.dp),
                            singleLine = false,
                            minLines = 5,
                            maxLines = 12,
                        )
                    }
                }
            }
        }
    }
}
