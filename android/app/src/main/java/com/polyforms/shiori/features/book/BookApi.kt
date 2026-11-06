package com.polyforms.shiori.features.book

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.graphql.AddBookMutation
import com.polyforms.shiori.graphql.BookCoverChoicesQuery
import com.polyforms.shiori.graphql.BookQuery
import com.polyforms.shiori.graphql.BookSagaVolumesQuery
import com.polyforms.shiori.graphql.ChooseBookCoverMutation
import com.polyforms.shiori.graphql.DeleteBookMutation
import com.polyforms.shiori.graphql.DescribeBookMutation
import com.polyforms.shiori.graphql.EditVocabularyQuery
import com.polyforms.shiori.graphql.RateBookMutation
import com.polyforms.shiori.graphql.RecordReadingPageMutation
import com.polyforms.shiori.graphql.SaveBookMutation
import com.polyforms.shiori.graphql.SetBookFavoriteMutation
import com.polyforms.shiori.graphql.SetBookHiddenMutation
import com.polyforms.shiori.graphql.SetBookNoteMutation
import com.polyforms.shiori.graphql.SetBookRecommendationMutation
import com.polyforms.shiori.graphql.SetReadingStatusMutation
import com.polyforms.shiori.graphql.SubgenresQuery
import com.polyforms.shiori.graphql.UpdateBookMutation
import com.polyforms.shiori.graphql.type.BookEditInput
import com.polyforms.shiori.graphql.type.NewBookInput
import com.polyforms.shiori.graphql.type.RecommendationInput
import com.polyforms.shiori.graphql.type.SeriesMembershipInput
import com.polyforms.shiori.graphql.type.SeriesPlacementInput
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.DataChange
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.ShowcaseData
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.asOptional
import com.polyforms.shiori.shared.asVolume
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.iso8601
import com.polyforms.shiori.shared.parseISO8601
import com.polyforms.shiori.shared.present
import com.polyforms.shiori.shared.track
import java.time.Instant
import java.time.LocalDate

data class BookVocabulary(val subgenres: List<String>, val sagas: List<String>)

/** A book about to be added: what a scan read, a form typed, or a catalogue proposed. */
data class BookDraft(
    val title: String,
    val authors: List<String> = emptyList(),
    val format: BookFormat = BookFormat.BOOK,
    val media: List<BookMedium> = listOf(BookMedium.PRINT),
    val publisher: String? = null,
    val firstPublishedIn: Int? = null,
    val synopsis: String? = null,
    val genre: BookGenre? = null,
    val subgenres: List<String> = emptyList(),
    val pageCount: Int? = null,
    val isbn13: String? = null,
    val language: BookLanguage? = null,
    val coverURL: String? = null,
    val series: SeriesMembership? = null,
    val status: ReadingStatus = ReadingStatus.TO_READ,
    val startedAt: Instant? = null,
    val finishedAt: Instant? = null,
    val hidden: Boolean = false,
    val rating: Double = 0.0,
    val favorite: Boolean = false,
) {
    val asInput: NewBookInput
        get() = NewBookInput(
            authors = authors.ifEmpty { null }.present(),
            coverUrl = coverURL.asOptional(),
            finishedAt = (if (status == ReadingStatus.READ) finishedAt?.let(::iso8601) else null).present(),
            firstPublishedIn = firstPublishedIn.present(),
            format = Optional.present(format.graphQL),
            genre = genre?.graphQL.present(),
            hidden = Optional.present(hidden),
            isbn13 = isbn13.asOptional(),
            language = language?.graphQL.present(),
            media = if (format == BookFormat.AUDIOBOOK) Optional.Absent else Optional.present(media.map { it.graphQL }),
            pageCount = pageCount.present(),
            publisher = publisher.asOptional(),
            series = series?.let { SeriesMembershipInput(id = it.id, kind = it.kind.graphQL, name = it.name, volume = it.volume.present()) }.present(),
            startedAt = (if (status == ReadingStatus.TO_READ) null else startedAt?.let(::iso8601)).present(),
            status = Optional.present(status.graphQL),
            subgenres = subgenres.ifEmpty { null }.present(),
            synopsis = synopsis.asOptional(),
            title = title,
        )

    /** The found draft, keeping what the reader chose: their format, media, saga, language, status. */
    fun completedBy(found: BookDraft): BookDraft = found.copy(
        title = found.title.ifEmpty { title },
        authors = found.authors.ifEmpty { authors },
        format = format,
        media = media,
        series = series ?: found.series,
        language = language ?: found.language,
        status = status,
    )
}

/** Where a book sits in a saga as the edit form says it. */
data class SeriesPlacement(val name: String, val volume: Int? = null, val annex: Boolean = false, val annexNumber: Int? = null)

/** A value an edit sets or clears; absent from the correction when the field is left as it was. */
sealed interface Change<out T> {
    data class Set<T>(val value: T) : Change<T>
    data object Clear : Change<Nothing>
}

private fun <T> Change<T>?.optional(): Optional<T?> = when (this) {
    null -> Optional.Absent
    is Change.Set -> Optional.present(value)
    Change.Clear -> Optional.present(null)
}

/** The fields an edit changes, and nothing else. */
data class BookCorrection(
    val title: String? = null,
    val authors: List<String>? = null,
    val format: BookFormat? = null,
    val media: List<BookMedium>? = null,
    val publisher: Change<String>? = null,
    val firstPublishedIn: Change<Int>? = null,
    val editionYear: Change<Int>? = null,
    val synopsis: Change<String>? = null,
    val genre: Change<BookGenre>? = null,
    val subgenres: List<String>? = null,
    val pageCount: Change<Int>? = null,
    val durationMinutes: Change<Int>? = null,
    val narrators: List<String>? = null,
    val isbn13: Change<String>? = null,
    val language: Change<BookLanguage>? = null,
    val series: Change<SeriesPlacement>? = null,
    val addedAt: Instant? = null,
    val startedAt: Instant? = null,
    val finishedAt: Instant? = null,
) {
    val isEmpty: Boolean get() = this == BookCorrection()

    val asInput: BookEditInput
        get() = BookEditInput(
            addedAt = Optional.presentIfNotNull(addedAt?.let(::iso8601)),
            authors = Optional.presentIfNotNull(authors),
            durationMinutes = durationMinutes.optional(),
            editionYear = editionYear.optional(),
            finishedAt = Optional.presentIfNotNull(finishedAt?.let(::iso8601)),
            firstPublishedIn = firstPublishedIn.optional(),
            format = Optional.presentIfNotNull(format?.graphQL),
            genre = when (val g = genre) {
                null -> Optional.Absent
                is Change.Set -> Optional.present(g.value.graphQL)
                Change.Clear -> Optional.present(null)
            },
            isbn13 = isbn13.optional(),
            language = when (val l = language) {
                null -> Optional.Absent
                is Change.Set -> Optional.present(l.value.graphQL)
                Change.Clear -> Optional.present(null)
            },
            media = Optional.presentIfNotNull(media?.map { it.graphQL }),
            narrators = Optional.presentIfNotNull(narrators),
            pageCount = pageCount.optional(),
            publisher = publisher.optional(),
            series = when (val s = series) {
                null -> Optional.Absent
                is Change.Set -> Optional.present(
                    SeriesPlacementInput(
                        annex = Optional.present(s.value.annex),
                        annexNumber = (if (s.value.annex) s.value.annexNumber else null).present(),
                        name = s.value.name,
                        volume = (if (s.value.annex) null else s.value.volume).present(),
                    ),
                )
                Change.Clear -> Optional.present(null)
            },
            startedAt = Optional.presentIfNotNull(startedAt?.let(::iso8601)),
            subgenres = Optional.presentIfNotNull(subgenres),
            synopsis = synopsis.optional(),
            title = Optional.presentIfNotNull(title),
        )
}

/** What a rating change asks: leave it, set it, or take it back. */
sealed interface RatingChange {
    data class Rate(val stars: Double) : RatingChange
    data object Unrate : RatingChange
}

object BookApi {
    suspend fun book(id: String): Book? {
        if (Showcase.isOn) return ShowcaseData.book(id)
        return GraphQLClient.fetch(BookQuery(id)).book?.bookDetail?.asBook
    }

    suspend fun sagaVolumes(seriesId: String, language: BookLanguage?): List<SeriesStripItem> {
        if (Showcase.isOn) {
            val screen = ShowcaseData.seriesScreen(seriesId)
            return SeriesStripItem.sagaRow(screen.owned, screen.series?.spine.orEmpty(), LocalDate.now().year, language)
        }
        val data = GraphQLClient.fetch(BookSagaVolumesQuery(seriesId))
        val catalogue = data.series?.takeUnless { it.awaitingCatalogue }?.catalogueSpine
        return SeriesStripItem.sagaRow(
            owned = data.mySeriesVolumes.map { it.bookSummary.asBook },
            spine = catalogue?.spine?.map { it.volumeEntry.asVolume }.orEmpty(),
            currentYear = LocalDate.now().year,
            language = language,
            catalogedAt = catalogue?.let { parseISO8601(it.catalogedAt) },
        )
    }

    suspend fun add(draft: BookDraft): Book = GraphQLClient.perform(AddBookMutation(draft.asInput)).addBook.bookDetail.asBook

    suspend fun setStatus(id: String, status: ReadingStatus): Book =
        GraphQLClient.perform(SetReadingStatusMutation(id, status.graphQL), DataChange.BookChange(id)).setReadingStatus.bookDetail.asBook

    suspend fun recordPage(id: String, page: Int): Book {
        if (Showcase.isOn) {
            val book = ShowcaseData.book(id)
            if (book != null) return book.copy(currentPage = page, status = if (book.status == ReadingStatus.TO_READ) ReadingStatus.READING else book.status)
        }
        return GraphQLClient.perform(RecordReadingPageMutation(id, page), DataChange.BookChange(id)).recordReadingPage.bookDetail.asBook
    }

    suspend fun update(id: String, correction: BookCorrection): Book =
        GraphQLClient.perform(UpdateBookMutation(id, correction.asInput), DataChange.BookChange(id)).updateBook.bookDetail.asBook

    suspend fun coverChoices(id: String): List<CoverChoice> {
        if (Showcase.isOn) return CoverChoice.previews
        return GraphQLClient.fetch(BookCoverChoicesQuery(id)).bookCoverChoices.mapNotNull { it.asDomain }
    }

    suspend fun chooseCover(id: String, url: String?): Book =
        GraphQLClient.perform(ChooseBookCoverMutation(id, url.asOptional()), DataChange.BookChange(id)).chooseBookCover.bookDetail.asBook

    suspend fun describe(id: String): Book =
        GraphQLClient.perform(DescribeBookMutation(id), DataChange.BookChange(id)).describeBook.bookDetail.asBook

    /** One request for an edit and a rating change together; null when nothing changed. */
    suspend fun save(id: String, correction: BookCorrection, rating: RatingChange?): Book? {
        val correct = !correction.isEmpty
        val rate = (rating as? RatingChange.Rate)?.stars
        val unrate = rating == RatingChange.Unrate
        if (!correct && rate == null && !unrate) return null
        val data = GraphQLClient.perform(
            SaveBookMutation(
                id = id,
                input = correction.asInput,
                correct = correct,
                rating = Optional.presentIfNotNull(rate),
                rate = rate != null,
                unrate = unrate,
            ),
            DataChange.BookChange(id),
        )
        if (rate != null) track(AnalyticsEvent.BookRated(rate))
        return (data.removeBookRating?.bookDetail ?: data.rateBook?.bookDetail ?: data.updateBook?.bookDetail)?.asBook
    }

    suspend fun rate(id: String, stars: Double): Book {
        val data = GraphQLClient.perform(RateBookMutation(id, stars), DataChange.BookChange(id))
        track(AnalyticsEvent.BookRated(stars))
        return data.rateBook.bookDetail.asBook
    }

    suspend fun setHidden(id: String, hidden: Boolean): Book =
        GraphQLClient.perform(SetBookHiddenMutation(id, hidden), DataChange.BookChange(id)).setBookHidden.bookDetail.asBook

    suspend fun setFavorite(id: String, favorite: Boolean): Book =
        GraphQLClient.perform(SetBookFavoriteMutation(id, favorite), DataChange.BookChange(id)).setBookFavorite.bookDetail.asBook

    suspend fun setRecommendation(id: String, recommendation: BookRecommendation?): Book {
        val input = recommendation?.let { RecommendationInput(comment = it.comment.asOptional(), recommenderName = it.recommenderName.asOptional()) }
        return GraphQLClient.perform(SetBookRecommendationMutation(id, Optional.present(input)), DataChange.BookChange(id))
            .setBookRecommendation.bookDetail.asBook
    }

    suspend fun setNote(id: String, note: String?): Book =
        GraphQLClient.perform(SetBookNoteMutation(id, Optional.present(note)), DataChange.BookChange(id)).setBookNote.bookDetail.asBook

    suspend fun vocabulary(): BookVocabulary {
        val data = GraphQLClient.fetch(EditVocabularyQuery())
        return BookVocabulary(data.vocabulary.subgenres, data.vocabulary.sagas)
    }

    suspend fun subgenres(): List<String> = GraphQLClient.fetch(SubgenresQuery()).subgenres

    suspend fun delete(id: String) {
        GraphQLClient.perform(DeleteBookMutation(id), DataChange.BookChange(id))
    }
}
