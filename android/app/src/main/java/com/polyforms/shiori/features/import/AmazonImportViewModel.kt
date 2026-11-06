package com.polyforms.shiori.features.import

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.reportError

/** An Amazon source's import: the connection, its library, the books picked, the syncs. */
class AmazonImportViewModel<Account : ImportAccount, Item : ImportItem>(
    val source: ImportSource,
    private val client: AmazonSourceClient<Account, Item>,
) {
    var account by mutableStateOf<Account?>(null)
        private set
    var books by mutableStateOf<List<Item>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isImporting by mutableStateOf(false)
        private set
    var isSyncing by mutableStateOf(false)
        private set
    var lastSyncOutcome by mutableStateOf<SyncOutcome?>(null)
        private set
    var hasReadLibrary by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var marketplace by mutableStateOf(AmazonMarketplace.suggested)
    var signIn by mutableStateOf<AmazonLogin?>(null)
    var selected by mutableStateOf<Set<String>>(emptySet())
        private set

    private val notConnected = if (source == ImportSource.AUDIBLE) "AUDIBLE_NOT_CONNECTED" else "KINDLE_NOT_CONNECTED"
    val importable: List<Item> get() = books.filter { !it.alreadyInLibrary }
    private val preselected: Set<String> get() = importable.filter { !it.removedByReader }.map { it.asin }.toSet()
    val canImport: Boolean get() = selected.isNotEmpty() && !isImporting
    val totalCount: Int? get() = if (hasReadLibrary) books.size else null
    val catalogedCount: Int? get() = if (hasReadLibrary) books.count { it.alreadyInLibrary } else null

    fun isSelected(book: Item) = book.asin in selected

    suspend fun load() {
        isLoading = true
        errorMessage = null
        lastSyncOutcome = null
        try {
            val connection = client.connection()
            account = connection?.first
            books = connection?.second.orEmpty()
            hasReadLibrary = connection != null
            selected = preselected
        } catch (error: Exception) {
            if ((error as? ApiError)?.domainCode == notConnected) {
                account = null
                books = emptyList()
            }
            hasReadLibrary = false
            errorMessage = reportError(error)
        } finally {
            isLoading = false
        }
    }

    suspend fun startSignIn() {
        errorMessage = null
        try {
            signIn = client.startSignIn(account?.marketplace ?: marketplace)
        } catch (error: Exception) {
            errorMessage = reportError(error)
        }
    }

    suspend fun finishSignIn(code: String) {
        signIn = null
        isLoading = true
        errorMessage = null
        try {
            account = client.completeSignIn(code)
        } catch (error: Exception) {
            errorMessage = reportError(error)
            isLoading = false
            return
        }
        load()
    }

    fun cancelSignIn() {
        signIn = null
    }

    fun toggle(book: Item) {
        if (book.alreadyInLibrary) return
        selected = if (book.asin in selected) selected - book.asin else selected + book.asin
    }

    fun selectAll() {
        selected = importable.map { it.asin }.toSet()
    }

    fun deselectAll() {
        selected = emptySet()
    }

    suspend fun importSelected(): List<Book> {
        if (!canImport) return emptyList()
        isImporting = true
        errorMessage = null
        return try {
            client.importBooks(selected.toList())
        } catch (error: Exception) {
            errorMessage = reportError(error)
            emptyList()
        } finally {
            isImporting = false
        }
    }

    suspend fun setAutoSync(enabled: Boolean) {
        if (account == null) return
        errorMessage = null
        try {
            account = client.setAutoSync(enabled)
        } catch (error: Exception) {
            errorMessage = reportError(error)
        }
    }

    suspend fun syncNow() {
        if (account == null || isSyncing) return
        isSyncing = true
        errorMessage = null
        try {
            val result = client.syncNow()
            account = result.account
            books = result.library.orEmpty()
            selected = preselected
            lastSyncOutcome = result.outcome
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            isSyncing = false
        }
    }

    suspend fun disconnect() {
        errorMessage = null
        try {
            client.disconnect()
            account = null
            books = emptyList()
            selected = emptySet()
            lastSyncOutcome = null
            hasReadLibrary = false
        } catch (error: Exception) {
            errorMessage = reportError(error)
        }
    }
}
