package com.polyforms.shiori.features.import

import com.polyforms.shiori.graphql.AudibleImportQuery
import com.polyforms.shiori.graphql.CompleteAudibleLoginMutation
import com.polyforms.shiori.graphql.CompleteKindleLoginMutation
import com.polyforms.shiori.graphql.DisconnectAudibleMutation
import com.polyforms.shiori.graphql.DisconnectKindleMutation
import com.polyforms.shiori.graphql.ImportAudibleBooksMutation
import com.polyforms.shiori.graphql.ImportKindleLibraryMutation
import com.polyforms.shiori.graphql.KindleImportQuery
import com.polyforms.shiori.graphql.SetAudibleAutoSyncMutation
import com.polyforms.shiori.graphql.SetKindleAutoSyncMutation
import com.polyforms.shiori.graphql.StartAudibleLoginMutation
import com.polyforms.shiori.graphql.StartKindleLoginMutation
import com.polyforms.shiori.graphql.SyncAudibleNowMutation
import com.polyforms.shiori.graphql.SyncKindleNowMutation
import com.polyforms.shiori.graphql.fragment.AudibleAccountSummary
import com.polyforms.shiori.graphql.fragment.ImportableAudibleBook
import com.polyforms.shiori.graphql.fragment.ImportableKindleBookFields
import com.polyforms.shiori.graphql.fragment.KindleAccountSummary
import com.polyforms.shiori.graphql.type.AudibleMarketplace
import com.polyforms.shiori.graphql.type.KindleMarketplace
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.parseISO8601
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch

/** What the import screens ask of an Amazon source, Audible or Kindle alike. */
interface AmazonSourceClient<Account, Item> {
    suspend fun connection(): Pair<Account, List<Item>>?
    suspend fun startSignIn(marketplace: AmazonMarketplace): AmazonLogin
    suspend fun completeSignIn(code: String): Account
    suspend fun importBooks(asins: List<String>): List<Book>
    suspend fun setAutoSync(enabled: Boolean): Account
    suspend fun syncNow(): SyncResult<Account, Item>
    suspend fun disconnect()
}

object ImportApi : AmazonSourceClient<AudibleAccount, ImportableBook> {
    override suspend fun connection(): Pair<AudibleAccount, List<ImportableBook>>? =
        GraphQLClient.fetch(AudibleImportQuery()).audibleAccount?.let { a -> a.audibleAccountSummary.asDomain to a.library.map { it.importableAudibleBook.asDomain } }

    override suspend fun startSignIn(marketplace: AmazonMarketplace): AmazonLogin {
        val login = GraphQLClient.perform(StartAudibleLoginMutation(AudibleMarketplace.safeValueOf(marketplace.graphQLName)), changesLibrary = false).startAudibleLogin
        return AmazonLogin(login.url, login.redirectUrl, login.cookies.map { AmazonLogin.Cookie(it.name, it.`value`, it.domain) })
    }

    override suspend fun completeSignIn(code: String): AudibleAccount =
        GraphQLClient.perform(CompleteAudibleLoginMutation(code), changesLibrary = false).completeAudibleLogin.audibleAccountSummary.asDomain

    override suspend fun importBooks(asins: List<String>): List<Book> =
        GraphQLClient.perform(ImportAudibleBooksMutation(asins)).importAudibleBooks.map { it.bookSummary.asBook }

    override suspend fun setAutoSync(enabled: Boolean): AudibleAccount =
        GraphQLClient.perform(SetAudibleAutoSyncMutation(enabled), changesLibrary = false).setAudibleAutoSync.audibleAccountSummary.asDomain

    override suspend fun syncNow(): SyncResult<AudibleAccount, ImportableBook> = syncNow(withLibrary = true)

    suspend fun syncNow(withLibrary: Boolean): SyncResult<AudibleAccount, ImportableBook> {
        val sync = GraphQLClient.perform(SyncAudibleNowMutation(withLibrary)).syncAudibleNow
        return SyncResult(SyncOutcome(sync.imported, sync.updated), sync.account.audibleAccountSummary.asDomain, sync.account.library?.map { it.importableAudibleBook.asDomain })
    }

    override suspend fun disconnect() {
        GraphQLClient.perform(DisconnectAudibleMutation(), changesLibrary = false)
    }
}

object KindleApi : AmazonSourceClient<KindleAccount, ImportableKindleBook> {
    override suspend fun connection(): Pair<KindleAccount, List<ImportableKindleBook>>? =
        GraphQLClient.fetch(KindleImportQuery()).kindleAccount?.let { a -> a.kindleAccountSummary.asDomain to a.library.map { it.importableKindleBookFields.asDomain } }

    override suspend fun startSignIn(marketplace: AmazonMarketplace): AmazonLogin {
        val login = GraphQLClient.perform(StartKindleLoginMutation(KindleMarketplace.safeValueOf(marketplace.graphQLName)), changesLibrary = false).startKindleLogin
        return AmazonLogin(login.url, login.redirectUrl, login.cookies.map { AmazonLogin.Cookie(it.name, it.`value`, it.domain) })
    }

    override suspend fun completeSignIn(code: String): KindleAccount =
        GraphQLClient.perform(CompleteKindleLoginMutation(code), changesLibrary = false).completeKindleLogin.kindleAccountSummary.asDomain

    override suspend fun importBooks(asins: List<String>): List<Book> =
        GraphQLClient.perform(ImportKindleLibraryMutation(asins)).importKindleLibrary.map { it.bookSummary.asBook }

    override suspend fun setAutoSync(enabled: Boolean): KindleAccount =
        GraphQLClient.perform(SetKindleAutoSyncMutation(enabled), changesLibrary = false).setKindleAutoSync.kindleAccountSummary.asDomain

    override suspend fun syncNow(): SyncResult<KindleAccount, ImportableKindleBook> = syncNow(withLibrary = true)

    suspend fun syncNow(withLibrary: Boolean): SyncResult<KindleAccount, ImportableKindleBook> {
        val sync = GraphQLClient.perform(SyncKindleNowMutation(withLibrary)).syncKindleNow
        return SyncResult(SyncOutcome(sync.imported, sync.updated), sync.account.kindleAccountSummary.asDomain, sync.account.library?.map { it.importableKindleBookFields.asDomain })
    }

    override suspend fun disconnect() {
        GraphQLClient.perform(DisconnectKindleMutation(), changesLibrary = false)
    }
}

val AudibleAccountSummary.asDomain: AudibleAccount
    get() = AudibleAccount(AmazonMarketplace.of(marketplace.rawValue), parseISO8601(connectedAt), parseISO8601(lastImportedAt), autoSync)

val KindleAccountSummary.asDomain: KindleAccount
    get() = KindleAccount(AmazonMarketplace.of(marketplace.rawValue), parseISO8601(connectedAt), parseISO8601(lastImportedAt), autoSync, parseISO8601(lastSyncFailedAt))

private val ImportableAudibleBook.asDomain: ImportableBook
    get() = ImportableBook(asin, title, authors, narrators, durationMinutes, coverUrl, seriesName, volume, status.asDomain, parseISO8601(finishedAt), alreadyInLibrary, removedByReader)

private val ImportableKindleBookFields.asDomain: ImportableKindleBook
    get() = ImportableKindleBook(asin, title, authors, coverUrl, seriesName, volume, status.asDomain, alreadyInLibrary, removedByReader)

/** A sync started in the background, after a sign-in: its spinner and its error, shared. */
class BackgroundSync(private val sync: suspend () -> Unit) {
    var isSyncing by androidx.compose.runtime.mutableStateOf(false)
        private set
    var errorMessage by androidx.compose.runtime.mutableStateOf<String?>(null)

    fun start(scope: kotlinx.coroutines.CoroutineScope) {
        if (isSyncing) return
        isSyncing = true
        errorMessage = null
        scope.launch {
            try {
                sync()
            } catch (error: Exception) {
                errorMessage = com.polyforms.shiori.shared.reportError(error)
            } finally {
                isSyncing = false
            }
        }
    }

    companion object {
        val audible = BackgroundSync { ImportApi.syncNow(withLibrary = false) }
        val kindle = BackgroundSync { KindleApi.syncNow(withLibrary = false) }
    }
}
