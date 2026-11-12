package com.polyforms.shiori.features.import.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.home.daysAgo
import com.polyforms.shiori.features.import.AmazonMarketplace
import com.polyforms.shiori.features.import.ImportAccount
import com.polyforms.shiori.features.import.ImportItem
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.import.SyncOutcome
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ToolbarMenuButton
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

private val ImportSource.pageSymbol: String get() = if (this == ImportSource.AUDIBLE) "headphones" else "book.closed"

@Composable
private fun PageColumn(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) { content() }
}

/** An Amazon source not connected yet: what the import does, the store, the connect button. */
@Composable
fun ImportConnectPage(source: ImportSource, marketplace: AmazonMarketplace, onMarketplace: (AmazonMarketplace) -> Unit, isWorking: Boolean, onConnect: () -> Unit) {
    val colors = Shiori.colors
    val audible = source == ImportSource.AUDIBLE
    PageColumn {
        FormSection {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Symbol(source.pageSymbol), null, Modifier.size(34.dp), tint = colors.accent)
                Text(if (audible) L("Importez votre bibliothèque Audible") else L("Importez votre bibliothèque Kindle"), style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = colors.label)
                Text(
                    if (audible) L("Connectez votre compte Amazon une fois, puis choisissez les livres audio à ajouter. Ils rejoignent votre bibliothèque avec leur couverture, leur série et votre avancement d'écoute.")
                    else L("Connectez votre compte Amazon une fois, puis choisissez les livres à ajouter. Ils rejoignent votre bibliothèque avec leur couverture et leur série, et ceux que vous avez finis sur Kindle sont marqués comme lus."),
                    style = Shiori.type.subheadline,
                    color = colors.secondaryLabel,
                )
            }
        }
        FormSection(L("Boutique"), footer = if (audible) L("Celle sur laquelle vous achetez vos livres audio.") else null) {
            MenuPicker(marketplace, AmazonMarketplace.entries, { if (audible) it.audibleLabel else it.amazonLabel }, onMarketplace, divider = false) {
                Text(if (audible) L("Boutique Audible") else L("Boutique Amazon"), style = Shiori.type.body, color = colors.label)
            }
        }
        FormSection(footer = if (audible) L("La page de connexion est celle d'Amazon : votre mot de passe ne passe jamais par Shiori. L'import ne consomme aucun scan.") else null) {
            FormRow(divider = false, onClick = if (isWorking) null else onConnect) {
                Text(L("Connecter mon compte Amazon"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.weight(1f))
                if (isWorking) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            }
        }
    }
}

/** A connected Amazon source: the account, the nightly sync, the library, the way out. */
@Composable
fun ImportSourcePage(
    source: ImportSource,
    account: ImportAccount,
    totalCount: Int?,
    catalogedCount: Int?,
    isLoading: Boolean,
    isSyncing: Boolean,
    lastSyncOutcome: SyncOutcome?,
    onAutoSyncChange: (Boolean) -> Unit,
    onSyncNow: () -> Unit,
    onPickBooks: () -> Unit,
    onReconnect: () -> Unit,
    onDisconnect: suspend () -> Unit,
) {
    val colors = Shiori.colors
    val audible = source == ImportSource.AUDIBLE
    PageColumn {
        if (account.lastSyncFailedAt != null) {
            FormSection {
                FormRow {
                    Icon(Symbol("exclamationmark.triangle.fill"), null, Modifier.size(20.dp), tint = colors.orange)
                    Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(L("Amazon a refusé la dernière synchronisation"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                        Text(L("Reconnectez votre compte pour que votre bibliothèque Kindle continue de vous suivre."), style = Shiori.type.caption, color = colors.secondaryLabel)
                    }
                }
                FormRow(divider = false, onClick = onReconnect) { Text(L("Reconnecter mon compte Amazon"), style = Shiori.type.body, color = colors.accent) }
            }
        }
        FormSection(L("Compte")) {
            Value(L("Boutique"), if (audible) account.marketplace.audibleLabel else account.marketplace.amazonLabel, divider = account.connectedAt != null)
            account.connectedAt?.let { Value(L("Connecté le"), DateText.dayMonthShortYear(DateText.local(it)), divider = false) }
        }
        FormSection(L("Synchronisation"), footer = lastSyncOutcome?.summary) {
            FormRow {
                Text(L("Synchroniser chaque nuit"), style = Shiori.type.body, color = colors.label, modifier = Modifier.weight(1f))
                ShioriSwitch(account.autoSync, onAutoSyncChange)
            }
            val last = account.lastImportedAt?.daysAgo()
            Value(L("Dernière synchronisation"), when (last) {
                null -> L("jamais")
                0 -> L("aujourd'hui")
                1 -> L("hier")
                else -> L("il y a %lldj", last)
            })
            FormRow(divider = false, onClick = if (isSyncing) null else onSyncNow) {
                Text(L("Synchroniser maintenant"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.weight(1f))
                if (isSyncing) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            }
        }
        FormSection(
            L("Bibliothèque"),
            footer = if (!audible && totalCount == 0) L("Aucun livre Kindle sur ce compte. Vérifiez la boutique : une bibliothèque française ne s'ouvre pas depuis amazon.com.") else null,
        ) {
            if (totalCount != null && catalogedCount != null) {
                Value(if (audible) L("Livres audio sur Audible") else L("Livres sur Kindle"), "$totalCount")
                Value(L("Déjà dans votre bibliothèque"), "$catalogedCount")
            } else {
                FormRow {
                    Text(if (audible) L("Lecture de votre bibliothèque Audible...") else L("Lecture de votre bibliothèque Kindle..."), style = Shiori.type.body, color = colors.secondaryLabel, modifier = Modifier.weight(1f))
                    if (isLoading) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                }
            }
            FormRow(divider = false, onClick = if ((totalCount ?: 0) == 0) null else onPickBooks) {
                Icon(Symbol("checklist"), null, Modifier.size(18.dp), tint = colors.accent)
                Text(L("Choisir des livres à importer"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.padding(start = 12.dp).alpha(if ((totalCount ?: 0) == 0) 0.4f else 1f))
            }
        }
        FormSection {
            Box(Modifier.fillMaxWidth().padding(vertical = 4.dp), contentAlignment = Alignment.Center) {
                ShioriButton(if (audible) L("Déconnecter Audible") else L("Déconnecter Kindle"), kind = ButtonKind.PLAIN, destructive = true) { onDisconnect() }
            }
        }
    }
}

@Composable
private fun Value(title: String, value: String, divider: Boolean = true) {
    FormRow(divider = divider) {
        Text(title, style = Shiori.type.body, color = Shiori.colors.label, modifier = Modifier.weight(1f))
        Text(value, style = Shiori.type.body, color = Shiori.colors.secondaryLabel)
    }
}

/** The books of an Amazon library, ticked to import; those already shelved greyed. */
@Composable
fun <Item : ImportItem> ImportLibraryPage(
    source: ImportSource,
    books: List<Item>,
    isLoading: Boolean,
    isImporting: Boolean,
    selectedCount: Int,
    canImport: Boolean,
    isSelected: (Item) -> Boolean,
    onToggle: (Item) -> Unit,
    onSelectAll: () -> Unit,
    onDeselectAll: () -> Unit,
    onImport: suspend () -> Unit,
) {
    val colors = Shiori.colors
    val audible = source == ImportSource.AUDIBLE
    Box(Modifier.fillMaxSize()) {
        when {
            isLoading && books.isEmpty() -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
                CircularProgressIndicator()
                Text(if (audible) L("Lecture de votre bibliothèque Audible...") else L("Lecture de votre bibliothèque Kindle..."), style = Shiori.type.subheadline, color = colors.secondaryLabel)
            }
            books.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyState(source.pageSymbol, L("Bibliothèque vide"), if (audible) L("Aucun livre audio sur ce compte.") else L("Aucun livre Kindle sur ce compte."))
            }
            else -> LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = PaddingValues(top = 64.dp, bottom = 140.dp)) {
                items(books, key = { it.asin }) { book ->
                    Row(
                        Modifier.fillMaxWidth().plainClickable(enabled = !book.alreadyInLibrary) { onToggle(book) }.alpha(if (book.alreadyInLibrary) 0.55f else 1f)
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            Symbol(if (book.alreadyInLibrary) "checkmark.circle" else if (isSelected(book)) "checkmark.circle.fill" else "circle"),
                            null,
                            Modifier.size(24.dp),
                            tint = if (book.alreadyInLibrary) colors.secondaryLabel else colors.accent,
                        )
                        BookCover(book.asCoverSubject, 44.dp)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(book.title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2)
                            Text(book.authorLine, style = Shiori.type.caption, color = colors.secondaryLabel, maxLines = 1)
                            if (book.detailLine.isNotEmpty()) Text(book.detailLine, style = Shiori.type.caption2, color = colors.tertiaryLabel, maxLines = 1)
                        }
                        when {
                            book.alreadyInLibrary -> Text(L("Déjà présent"), style = Shiori.type.caption2, color = colors.secondaryLabel)
                            book.status != ReadingStatus.TO_READ -> Icon(Symbol(book.status.symbol), book.status.label, Modifier.size(14.dp), tint = colors.secondaryLabel)
                        }
                    }
                    ShioriDivider(Modifier.padding(start = 92.dp))
                }
            }
        }
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(colors.secondaryGroupedBackground).navigationBarsPadding().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ShioriButton(
                if (selectedCount == 0) L("Sélectionnez des livres") else L("Importer %lld livre(s)", selectedCount),
                enabled = canImport,
                large = true,
                fillWidth = true,
            ) { onImport() }
            if (isImporting) Text(L("Import en cours, gardez l'écran ouvert..."), style = Shiori.type.caption, color = colors.secondaryLabel)
        }
        Box(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(16.dp)) {
            ToolbarMenuButton(L("Options"), "ellipsis.circle", listOf(MenuEntry.Item(L("Tout sélectionner"), action = onSelectAll), MenuEntry.Item(L("Tout désélectionner"), action = onDeselectAll)))
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ImportPagesPreview() = PreviewSurface {
    ImportConnectPage(
        com.polyforms.shiori.features.import.ImportSource.AUDIBLE,
        com.polyforms.shiori.features.import.AmazonMarketplace.FR,
        onMarketplace = {},
        isWorking = false,
    ) {}
}
