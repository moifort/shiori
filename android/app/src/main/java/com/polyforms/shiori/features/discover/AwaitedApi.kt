package com.polyforms.shiori.features.discover

import com.polyforms.shiori.graphql.AwaitBookEditionMutation
import com.polyforms.shiori.graphql.AwaitFriendBookEditionMutation
import com.polyforms.shiori.graphql.AwaitScannedEditionMutation
import com.polyforms.shiori.graphql.AwaitedEditionsQuery
import com.polyforms.shiori.graphql.BookEditionOfferQuery
import com.polyforms.shiori.graphql.DraftEditionFormatsQuery
import com.polyforms.shiori.graphql.FriendBookEditionOfferQuery
import com.polyforms.shiori.graphql.StopAwaitingEditionMutation
import com.polyforms.shiori.graphql.fragment.AwaitedEditionFields
import com.polyforms.shiori.graphql.fragment.EditionOfferFields
import com.polyforms.shiori.graphql.type.AwaitedState as GAwaitedState
import com.polyforms.shiori.graphql.type.ReleaseFormat as GReleaseFormat
import com.polyforms.shiori.graphql.type.ScannedBookInput
import com.polyforms.shiori.graphql.type.SeriesPlacementInput
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.asOptional
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.parseISO8601
import com.polyforms.shiori.shared.present
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/** The saga read or the saga heard: Découvrir asks for each apart and draws them mixed. */
@Serializable
enum class ReleaseFormat {
    BOOK, AUDIOBOOK;

    val symbol: String get() = if (this == BOOK) "book" else "headphones"
    val graphQL: GReleaseFormat get() = if (this == BOOK) GReleaseFormat.BOOK else GReleaseFormat.AUDIOBOOK

    val awaitLabel: String get() = if (this == BOOK) L("Guetter en français") else L("Guetter en audio")
    val awaitedTitle: String get() = if (this == BOOK) L("Bientôt en FR") else L("Bientôt en audio")
    val storeName: String get() = if (this == BOOK) "Amazon" else "Audible"
    val usesAudibleTint: Boolean get() = this == AUDIOBOOK

    companion object {
        fun of(format: GReleaseFormat): ReleaseFormat? = when (format) {
            GReleaseFormat.BOOK -> BOOK
            GReleaseFormat.AUDIOBOOK -> AUDIOBOOK
            else -> null
        }
    }
}

@Serializable
enum class AwaitedState { UNANNOUNCED, ANNOUNCED, AVAILABLE }

/** An edition the reader awaits: a translation, a recording, and where it stands. */
@Serializable
data class AwaitedEdition(
    val id: String,
    val format: ReleaseFormat,
    val state: AwaitedState,
    val title: String,
    val originalTitle: String,
    val originalLanguage: BookLanguage?,
    val authors: List<String>,
    val date: String?,
    val coverURL: String?,
    val storeURL: String?,
    @Serializable(InstantSerializer::class) val awaitedAt: Instant?,
    val bookId: String?,
    val ownerId: String,
) {
    val caption: String
        get() = when (state) {
            AwaitedState.AVAILABLE -> L("Disponible")
            AwaitedState.ANNOUNCED -> date?.let(ReleaseDateText::short) ?: L("Annoncé")
            AwaitedState.UNANNOUNCED -> L("Pas annoncé")
        }

    val stateLine: String
        get() = when (state) {
            AwaitedState.AVAILABLE -> date?.let { L("Sorti %@", ReleaseDateText.phrase(it)) } ?: L("Disponible")
            AwaitedState.ANNOUNCED -> date?.let(ReleaseDateText::coming) ?: L("Annoncé, sans date")
            AwaitedState.UNANNOUNCED -> L("Pas encore annoncé")
        }

    val stateTint: SystemTint?
        get() = when (state) {
            AwaitedState.AVAILABLE -> SystemTint.GREEN
            AwaitedState.ANNOUNCED -> SystemTint.ORANGE
            AwaitedState.UNANNOUNCED -> null
        }

    val cover: Book
        get() = Book(
            id = "awaited-$id",
            title = title,
            authors = authors,
            format = if (format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            coverURL = coverURL,
            status = ReadingStatus.TO_READ,
        )

    val isAddable: Boolean get() = state != AwaitedState.UNANNOUNCED

    val announcedDate: String?
        get() = if (state == AwaitedState.ANNOUNCED && date != null && ReleaseDateText.isUpcoming(date)) date else null

    val pageState: BookState?
        get() = if (announcedDate == null) BookState(stateLine, stateTint ?: SystemTint.GRAY) else null

    fun draft(shown: Book): BookDraft = BookDraft(
        title = shown.title,
        authors = shown.authors,
        format = if (format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else shown.format,
        genre = shown.genre,
        subgenres = shown.subgenres,
        synopsis = shown.synopsis,
        publisher = shown.publisher,
        firstPublishedIn = shown.firstPublishedIn,
        pageCount = shown.pageCount,
        isbn13 = shown.isbn13,
        series = shown.series,
        coverURL = shown.coverURL,
        status = ReadingStatus.TO_READ,
    )

    companion object {
        fun pending(format: ReleaseFormat, book: Book) = AwaitedEdition(
            "pending-${book.id}-${format.name.lowercase()}", format, AwaitedState.UNANNOUNCED, book.title, book.title,
            null, book.authors, null, null, null, Instant.now(), book.id, "",
        )

        fun pending(format: ReleaseFormat, draft: BookDraft) = AwaitedEdition(
            "pending-${UUID.randomUUID()}", format, AwaitedState.UNANNOUNCED, draft.title, draft.title,
            draft.language, draft.authors, null, draft.coverURL, null, Instant.now(), null, "",
        )
    }
}

/** What a book's page offers to await: the formats the server can watch, those already awaited. */
data class EditionOffer(val formats: List<ReleaseFormat> = emptyList(), val awaited: List<AwaitedEdition> = emptyList()) {
    val awaitable: List<ReleaseFormat> get() = formats.filter { f -> awaited.none { it.format == f } }
}

val AwaitedEditionFields.asDomain: AwaitedEdition
    get() = AwaitedEdition(
        id = id,
        format = if (format == GReleaseFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK,
        state = when (state) {
            GAwaitedState.AVAILABLE -> AwaitedState.AVAILABLE
            GAwaitedState.ANNOUNCED -> AwaitedState.ANNOUNCED
            else -> AwaitedState.UNANNOUNCED
        },
        title = title,
        originalTitle = originalTitle,
        originalLanguage = originalLanguage.asDomain,
        authors = authors,
        date = date,
        coverURL = coverUrl,
        storeURL = storeUrl,
        awaitedAt = parseISO8601(awaitedAt),
        bookId = sourceBookId,
        ownerId = ownerId,
    )

private val EditionOfferFields.asDomain: EditionOffer
    get() = EditionOffer(formats.mapNotNull(ReleaseFormat::of), awaited.map { it.awaitedEditionFields.asDomain })

object AwaitedApi {
    /** Posted when an edition starts or stops being awaited, so Découvrir's strip follows. */
    private val changes = MutableSharedFlow<Unit>(extraBufferCapacity = 4)
    val didChange: SharedFlow<Unit> get() = changes

    suspend fun awaited(format: ReleaseFormat): List<AwaitedEdition> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(AwaitedEditionsQuery(format.graphQL)).awaitedEditions.map { it.awaitedEditionFields.asDomain }
    }

    suspend fun offer(bookId: String): EditionOffer? {
        if (Showcase.isOn) return null
        return GraphQLClient.fetch(BookEditionOfferQuery(bookId)).bookEditionOffer?.editionOfferFields?.asDomain
    }

    suspend fun formats(language: BookLanguage, format: BookFormat): List<ReleaseFormat> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(DraftEditionFormatsQuery(language.graphQL, format.graphQL)).draftEditionFormats.mapNotNull(ReleaseFormat::of)
    }

    suspend fun offer(friendId: String, bookId: String): EditionOffer? =
        GraphQLClient.fetch(FriendBookEditionOfferQuery(friendId, bookId)).friendBookEditionOffer?.editionOfferFields?.asDomain

    suspend fun awaitEdition(bookId: String, format: ReleaseFormat): AwaitedEdition {
        val data = GraphQLClient.perform(AwaitBookEditionMutation(bookId, format.graphQL), changesLibrary = false)
        changes.tryEmit(Unit)
        return data.awaitBookEdition.awaitedEditionFields.asDomain
    }

    suspend fun awaitEdition(friendId: String, bookId: String, format: ReleaseFormat): AwaitedEdition {
        val data = GraphQLClient.perform(AwaitFriendBookEditionMutation(friendId, bookId, format.graphQL), changesLibrary = false)
        changes.tryEmit(Unit)
        return data.awaitFriendBookEdition.awaitedEditionFields.asDomain
    }

    suspend fun awaitScanned(draft: BookDraft, format: ReleaseFormat): AwaitedEdition {
        val book = ScannedBookInput(
            authors = draft.authors.ifEmpty { null }.present(),
            coverUrl = draft.coverURL.asOptional(),
            format = draft.format.graphQL,
            language = draft.language?.graphQL.present(),
            series = draft.series?.let { SeriesPlacementInput(name = it.name, volume = it.volume.present()) }.present(),
            title = draft.title,
        )
        val data = GraphQLClient.perform(AwaitScannedEditionMutation(book, format.graphQL), changesLibrary = false)
        changes.tryEmit(Unit)
        return data.awaitScannedEdition.awaitedEditionFields.asDomain
    }

    suspend fun stop(id: String) {
        GraphQLClient.perform(StopAwaitingEditionMutation(id), changesLibrary = false)
        changes.tryEmit(Unit)
    }
}
