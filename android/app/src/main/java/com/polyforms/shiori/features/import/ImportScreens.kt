package com.polyforms.shiori.features.import

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.import.components.pages.ImportConnectPage
import com.polyforms.shiori.features.import.components.pages.ImportLibraryPage
import com.polyforms.shiori.features.import.components.pages.ImportSourcePage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.AmazonSignInSheet
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** An Amazon source's import, connected: sign-in, sync, the books to pick. */
@Composable
fun <Account : ImportAccount, Item : ImportItem> AmazonImportScreen(source: ImportSource, client: AmazonSourceClient<Account, Item>, onImported: () -> Unit) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(source) { AmazonImportViewModel(source, client) }
    val navigator = currentNavigator
    LaunchedEffect(source) { viewModel.load() }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val account = viewModel.account
        if (account != null) {
            ImportSourcePage(
                source,
                account,
                viewModel.totalCount,
                viewModel.catalogedCount,
                viewModel.isLoading,
                viewModel.isSyncing,
                viewModel.lastSyncOutcome,
                onAutoSyncChange = { scope.launch { viewModel.setAutoSync(it) } },
                onSyncNow = { scope.launch { viewModel.syncNow() } },
                onPickBooks = {
                    navigator.push {
                        Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
                            ImportLibraryPage(
                                source,
                                viewModel.books,
                                viewModel.isLoading,
                                viewModel.isImporting,
                                viewModel.selected.size,
                                viewModel.canImport,
                                viewModel::isSelected,
                                viewModel::toggle,
                                viewModel::selectAll,
                                viewModel::deselectAll,
                            ) {
                                val imported = viewModel.importSelected()
                                if (imported.isNotEmpty()) {
                                    navigator.pop()
                                    onImported()
                                }
                            }
                            ScreenBar(title = L("Choisir des livres"))
                        }
                    }
                },
                onReconnect = { scope.launch { viewModel.startSignIn() } },
                onDisconnect = { viewModel.disconnect() },
            )
        } else {
            ImportConnectPage(source, viewModel.marketplace, { viewModel.marketplace = it }, viewModel.isLoading) { scope.launch { viewModel.startSignIn() } }
        }
        ScreenBar(title = source.label)
    }
    viewModel.signIn?.let { login ->
        AmazonSignInSheet(login, onCode = { code -> scope.launch { viewModel.finishSignIn(code) } }, onCancel = viewModel::cancelSignIn)
    }
    viewModel.errorMessage?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.errorMessage = null }) }
}

@Composable
fun AudibleImportScreen(onImported: () -> Unit) = AmazonImportScreen(ImportSource.AUDIBLE, ImportApi, onImported)

@Composable
fun KindleImportScreen(onImported: () -> Unit) = AmazonImportScreen(ImportSource.KINDLE, KindleApi, onImported)
