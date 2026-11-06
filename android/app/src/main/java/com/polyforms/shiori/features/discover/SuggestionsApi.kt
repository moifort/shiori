package com.polyforms.shiori.features.discover

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.graphql.DismissSuggestionMutation
import com.polyforms.shiori.graphql.MonthlyDiscoveriesQuery
import com.polyforms.shiori.graphql.ReconsiderSuggestionMutation
import com.polyforms.shiori.graphql.fragment.SuggestionFields
import com.polyforms.shiori.graphql.type.DiscoveriesStatus
import com.polyforms.shiori.graphql.type.SuggestionKind
import com.polyforms.shiori.graphql.type.DismissalReason as GDismissal
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.asDomain
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneOffset
import java.time.format.TextStyle
import java.util.Locale

/** A book of the reader's a suggestion leans on. */
@Serializable
data class SuggestionReference(
    val bookId: String,
    val seriesId: String?,
    val title: String,
    val favorite: Boolean,
    val rating: Double?,
    val viaSeries: Boolean,
    val coverURL: String? = null,
    val citesSaga: Boolean = false,
) {
    val id: String get() = bookId
    val cover: Book get() = Book(id = bookId, title = title, authors = emptyList(), coverURL = coverURL, status = ReadingStatus.READ)
}

enum class DismissalReason { NOT_INTERESTED, DISLIKED }

@Serializable
data class Suggestion(
    override val id: String,
    val format: ReleaseFormat,
    val title: String,
    val originalTitle: String,
    val originalLanguage: BookLanguage?,
    val authors: List<String>,
    val reason: String,
    val short: String,
    val references: List<SuggestionReference>,
    val state: AwaitedState,
    val watched: Boolean,
    val date: String?,
    val coverURL: String?,
    val storeURL: String?,
    override val awaitableFormats: List<ReleaseFormat>,
    val awaitedEditionId: String?,
    val drawnFormat: BookFormat? = null,
) : Discovery {
    val leadReference: SuggestionReference? get() = references.firstOrNull()

    val cover: Book
        get() = Book(id = "suggestion-$id", title = title, authors = authors, format = if (format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else drawnFormat ?: BookFormat.BOOK, coverURL = coverURL, status = ReadingStatus.TO_READ)

    val draft: BookDraft get() = BookDraft(title = originalTitle, authors = authors, format = drawnFormat ?: BookFormat.BOOK, language = originalLanguage)

    val stateLine: String
        get() = when (state) {
            AwaitedState.AVAILABLE -> L("Disponible")
            AwaitedState.ANNOUNCED -> date?.let(ReleaseDateText::coming) ?: L("Annoncé, sans date")
            AwaitedState.UNANNOUNCED -> if (format == ReleaseFormat.AUDIOBOOK) L("Pas encore en audio") else L("Non traduit")
        }

    val stateTint: SystemTint
        get() = when (state) {
            AwaitedState.AVAILABLE -> SystemTint.GREEN
            AwaitedState.ANNOUNCED -> SystemTint.ORANGE
            AwaitedState.UNANNOUNCED -> SystemTint.GRAY
        }

    val seed: ReleaseSeed
        get() = ReleaseSeed(title, authors, if (format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else drawnFormat ?: BookFormat.BOOK, if (state == AwaitedState.UNANNOUNCED) originalLanguage else null, releasedOn = date, coverURL = coverURL)
}

/** The month's discoveries Claude chose for the reader. */
@Serializable
data class MonthlyDiscoveries(
    val month: String,
    val status: Status = Status.READY,
    val suggestions: List<Suggestion>,
    val needsRatings: Boolean = false,
) {
    enum class Status { READY, SEARCHING, NONE }

    val title: String get() = title(month)

    val nextLine: String get() = L("Plus de découvertes ce mois-ci : prochaines en %@.", monthName(month(after = month)))

    companion object {
        private fun monthName(month: String, locale: Locale = Locale.getDefault()): String =
            runCatching { YearMonth.parse(month).month.getDisplayName(TextStyle.FULL_STANDALONE, locale) }.getOrDefault(month)

        private fun elided(name: String) = name.lowercase().firstOrNull()?.let { it in "aeiouyéèh" } ?: false

        fun title(month: String): String {
            val name = monthName(month)
            return if (elided(name)) L("Les découvertes d’%@", name) else L("Les découvertes de %@", name)
        }

        fun badge(month: String): String {
            val name = monthName(month)
            return if (elided(name)) L("Découverte d’%@", name) else L("Découverte de %@", name)
        }

        fun arrivingTitle(month: String): String {
            val name = monthName(month)
            return if (elided(name)) L("Vos livres d’%@ arrivent", name) else L("Vos livres de %@ arrivent", name)
        }

        fun nextArrivalLine(month: String): String = L("Les prochaines arrivent en %@", monthName(month(after = month)))

        fun month(of: Instant): String {
            val date = of.atZone(ZoneOffset.UTC)
            return "%04d-%02d".format(date.year, date.monthValue)
        }

        fun month(after: String): String = runCatching { YearMonth.parse(after).plusMonths(1).toString() }.getOrDefault(after)
    }
}

object SuggestionsApi {
    suspend fun monthly(format: ReleaseFormat, lookUp: Boolean): MonthlyDiscoveries {
        if (Showcase.isOn) return MonthlyDiscoveries("2026-10", suggestions = emptyList())
        val data = GraphQLClient.fetch(MonthlyDiscoveriesQuery(format.graphQL, Optional.present(lookUp))).monthlyDiscoveries
        return MonthlyDiscoveries(
            month = data.month,
            status = when (data.status) {
                DiscoveriesStatus.READY -> MonthlyDiscoveries.Status.READY
                DiscoveriesStatus.SEARCHING -> MonthlyDiscoveries.Status.SEARCHING
                else -> MonthlyDiscoveries.Status.NONE
            },
            suggestions = data.suggestions.map { it.suggestionFields.asDomain },
            needsRatings = data.needsRatings,
        )
    }

    suspend fun dismiss(id: String, reason: DismissalReason) {
        val told = if (reason == DismissalReason.DISLIKED) GDismissal.DISLIKED else GDismissal.NOT_INTERESTED
        GraphQLClient.perform(DismissSuggestionMutation(id, told), changesLibrary = false)
    }

    suspend fun reconsider(id: String) {
        GraphQLClient.perform(ReconsiderSuggestionMutation(id), changesLibrary = false)
    }
}

val SuggestionFields.asDomain: Suggestion
    get() = Suggestion(
        id = id,
        format = format.asRelease(),
        title = title,
        originalTitle = originalTitle,
        originalLanguage = originalLanguage.asDomain,
        authors = authors,
        reason = reason,
        short = short,
        references = references.map { SuggestionReference(it.bookId, it.seriesId, it.title, it.favorite, it.rating, it.viaSeries, it.coverUrl, it.citesSaga) },
        state = state.asAwaited(),
        watched = watched,
        date = date,
        coverURL = coverUrl,
        storeURL = storeUrl,
        awaitableFormats = awaitableFormats.mapNotNull(ReleaseFormat::of),
        awaitedEditionId = awaitedEditionId,
        drawnFormat = when (kind) {
            SuggestionKind.BANDE_DESSINEE -> BookFormat.BANDE_DESSINEE
            SuggestionKind.COMIC -> BookFormat.COMIC
            SuggestionKind.MANGA -> BookFormat.MANGA
            else -> null
        },
    )

/** The suggestion as a book of the reader's shelf, in the edition it was proposed in. */
fun Suggestion.shelfDraft(status: com.polyforms.shiori.shared.ReadingStatus): BookDraft {
    val format = if (this.format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else BookFormat.BOOK
    return draft.copy(
        title = title,
        language = null,
        coverURL = coverURL,
        format = format,
        media = if (format == BookFormat.AUDIOBOOK) emptyList() else draft.media,
        status = status,
    )
}
