package com.polyforms.shiori.features.import

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import java.time.Instant
import java.util.Locale

/** The Amazon store an Audible or Kindle account belongs to. */
enum class AmazonMarketplace(val graphQLName: String, val audibleLabel: String, val amazonLabel: String) {
    FR("FR", "audible.fr", "amazon.fr"),
    COM("COM", "audible.com", "amazon.com"),
    CO_UK("CO_UK", "audible.co.uk", "amazon.co.uk"),
    DE("DE", "audible.de", "amazon.de"),
    IT("IT", "audible.it", "amazon.it"),
    ES("ES", "audible.es", "amazon.es"),
    CA("CA", "audible.ca", "amazon.ca"),
    COM_AU("COM_AU", "audible.com.au", "amazon.com.au"),
    INDIA("IN", "audible.in", "amazon.in"),
    CO_JP("CO_JP", "audible.co.jp", "amazon.co.jp");

    companion object {
        fun of(name: String): AmazonMarketplace = entries.firstOrNull { it.graphQLName == name } ?: COM

        /** The store the phone's language and region point to. */
        val suggested: AmazonMarketplace get() = suggested(Locale.getDefault().language, Locale.getDefault().country)

        fun suggested(language: String?, region: String?): AmazonMarketplace = when (language) {
            "fr" -> if (region == "CA") CA else FR
            "de" -> DE
            "it" -> IT
            "es" -> ES
            "ja" -> CO_JP
            "en" -> when (region) {
                "GB", "IE" -> CO_UK
                "CA" -> CA
                "AU", "NZ" -> COM_AU
                "IN" -> INDIA
                else -> COM
            }
            else -> when (region) {
                "FR", "BE", "LU", "CH" -> FR
                "GB", "IE" -> CO_UK
                "DE", "AT" -> DE
                "IT" -> IT
                "ES" -> ES
                "CA" -> CA
                "AU", "NZ" -> COM_AU
                "IN" -> INDIA
                "JP" -> CO_JP
                else -> COM
            }
        }
    }
}

data class AudibleAccount(override val marketplace: AmazonMarketplace, override val connectedAt: Instant?, override val lastImportedAt: Instant?, override val autoSync: Boolean) : ImportAccount

data class KindleAccount(override val marketplace: AmazonMarketplace, override val connectedAt: Instant?, override val lastImportedAt: Instant?, override val autoSync: Boolean, override val lastSyncFailedAt: Instant?) : ImportAccount

/** The Amazon sign-in page the server prepared: where to open it, what ends it, its cookies. */
data class AmazonLogin(val url: String, val redirectURL: String, val cookies: List<Cookie>) {
    data class Cookie(val name: String, val value: String, val domain: String)

    val id: String get() = url
}

/** A recording of the reader's Audible library, offered to import. */
data class ImportableBook(
    override val asin: String,
    override val title: String,
    val authors: List<String>,
    val narrators: List<String>,
    val durationMinutes: Int?,
    val coverURL: String?,
    val seriesName: String?,
    val volume: Int?,
    override val status: ReadingStatus,
    val finishedAt: Instant?,
    override val alreadyInLibrary: Boolean,
    override val removedByReader: Boolean = false,
) : ImportItem {
    val id: String get() = asin
    override val authorLine: String get() = if (authors.isEmpty()) L("Auteur inconnu") else authors.joinToString(", ")

    override val detailLine: String
        get() = buildList {
            seriesName?.let { add(volume?.let { v -> "$it $v" } ?: it) }
            durationMinutes?.takeIf { it > 0 }?.let { m -> add(if (m / 60 > 0) "${m / 60}h${"%02d".format(m % 60)}" else "${m}min") }
            if (narrators.isNotEmpty()) add(narrators.joinToString(", "))
        }.joinToString(" · ")

    override val asCoverSubject: Book get() = Book(id = asin, title = title, authors = authors, coverURL = coverURL, status = status)
}

/** A book of the reader's Kindle library, offered to import. */
data class ImportableKindleBook(
    override val asin: String,
    override val title: String,
    val authors: List<String>,
    val coverURL: String?,
    val seriesName: String?,
    val volume: Int?,
    override val status: ReadingStatus,
    override val alreadyInLibrary: Boolean,
    override val removedByReader: Boolean = false,
) : ImportItem {
    val id: String get() = asin
    override val authorLine: String get() = if (authors.isEmpty()) L("Auteur inconnu") else authors.joinToString(", ")
    override val detailLine: String get() = seriesName?.let { s -> volume?.let { "$s $it" } ?: s } ?: ""
    override val asCoverSubject: Book get() = Book(id = asin, title = title, authors = authors, coverURL = coverURL, status = status)
}

enum class ImportSource {
    AUDIBLE, KINDLE;

    val label: String get() = if (this == AUDIBLE) "Audible" else "Kindle"
    val symbol: String get() = if (this == AUDIBLE) "headphones" else "ipad"
    val subtitle: String get() = L("Connexion, import et synchronisation")
}

/** What a sync brought: books added, books moved. */
data class SyncOutcome(val imported: Int, val updated: Int) {
    val summary: String
        get() = when {
            imported == 0 && updated == 0 -> L("Rien de nouveau depuis la dernière fois.")
            updated == 0 -> L("%lld livre(s) ajouté(s).", imported)
            imported == 0 -> L("%lld livre(s) mis à jour.", updated)
            else -> L("%lld livre(s) ajouté(s), %lld mis à jour.", imported, updated)
        }
}

/** A sync's answer: what it brought, the account after it, the library offered again. */
data class SyncResult<Account, Item>(val outcome: SyncOutcome, val account: Account, val library: List<Item>?)

/** An Amazon account as the import screens show it, Audible or Kindle alike. */
interface ImportAccount {
    val marketplace: AmazonMarketplace
    val connectedAt: Instant?
    val lastImportedAt: Instant?
    val autoSync: Boolean
    val lastSyncFailedAt: Instant? get() = null
}

/** A book of an Amazon library offered to import. */
interface ImportItem {
    val asin: String
    val title: String
    val authorLine: String
    val detailLine: String
    val asCoverSubject: Book
    val status: ReadingStatus
    val alreadyInLibrary: Boolean
    val removedByReader: Boolean
}
