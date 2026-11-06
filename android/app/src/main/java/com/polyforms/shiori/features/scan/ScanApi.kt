package com.polyforms.shiori.features.scan

import android.util.Base64
import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.graphql.AddDetectedBookMutation
import com.polyforms.shiori.graphql.DetectBooksMutation
import com.polyforms.shiori.graphql.LookUpTitleMutation
import com.polyforms.shiori.graphql.ScanBookMutation
import com.polyforms.shiori.graphql.ScanLinkMutation
import com.polyforms.shiori.graphql.ScanSeriesVolumeMutation
import com.polyforms.shiori.graphql.SearchTitleMutation
import com.polyforms.shiori.graphql.fragment.ScannedRecord
import com.polyforms.shiori.graphql.type.DetectedBookInput
import com.polyforms.shiori.graphql.type.SeriesVolumeInput
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.present

/** What the AI read off a cover, a link or a title. */
data class ScannedBook(
    val recognized: Boolean,
    val title: String? = null,
    val authors: List<String> = emptyList(),
    val format: BookFormat? = null,
    val media: List<BookMedium> = emptyList(),
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
    val ownedCopy: Book? = null,
) {
    val asDraft: BookDraft
        get() = BookDraft(
            title = title ?: "",
            authors = authors,
            format = format ?: BookFormat.BOOK,
            media = media.ifEmpty { listOf(BookMedium.PRINT) },
            publisher = publisher,
            firstPublishedIn = firstPublishedIn,
            synopsis = synopsis,
            genre = genre,
            subgenres = subgenres,
            pageCount = pageCount,
            isbn13 = isbn13,
            language = BookLanguage.presumed(language),
            coverURL = coverURL,
            series = series,
        )
}

/** A book a typed title may name, as the search proposes it. */
data class TitleCandidate(val title: String, val authors: List<String>, val firstPublishedIn: Int?, val seriesName: String?, val volume: Int?) {
    val id: String get() = "$title|${authors.joinToString(",")}"
    val lookUpQuery: String get() = authors.firstOrNull()?.let { "$title — $it" } ?: title
}

/** Where a spine sits in a shelf photo, as fractions of its width and height. */
data class NormalizedBox(val x: Double, val y: Double, val width: Double, val height: Double)

/** A book read off a shelf photo. */
data class DetectedBook(
    val id: Int,
    val title: String?,
    val authors: List<String>,
    val publisher: String?,
    val language: BookLanguage?,
    val format: BookFormat?,
    val media: List<BookMedium> = emptyList(),
    val seriesName: String?,
    val volume: Int?,
    val box: NormalizedBox,
    val owned: Boolean,
) {
    val byline: String? get() = authors.ifEmpty { null }?.joinToString(", ")
    val seriesLabel: String? get() = seriesName?.let { name -> volume?.let { "$name · ${L("Tome %lld", it)}" } ?: name }
    val isNamed: Boolean get() = !title.isNullOrEmpty()
}

object ScanApi {
    private fun base64(jpeg: ByteArray) = Base64.encodeToString(jpeg, Base64.NO_WRAP)

    suspend fun scan(jpeg: ByteArray): ScannedBook =
        GraphQLClient.perform(ScanBookMutation(base64(jpeg)), changesLibrary = false).scanBook.scannedRecord.asDomain

    suspend fun lookUpLink(link: String): ScannedBook =
        GraphQLClient.perform(ScanLinkMutation(link), changesLibrary = false).scanLink.scannedRecord.asDomain

    suspend fun searchTitle(title: String): List<TitleCandidate> =
        GraphQLClient.perform(SearchTitleMutation(title), changesLibrary = false).searchTitle.map {
            TitleCandidate(it.title, it.authors, it.firstPublishedIn, it.seriesName, it.volume)
        }

    suspend fun lookUpTitle(title: String): ScannedBook =
        GraphQLClient.perform(LookUpTitleMutation(title), changesLibrary = false).scanTitle.scannedRecord.asDomain

    suspend fun lookUpVolume(title: String, author: String, membership: SeriesMembership, format: BookFormat, media: List<BookMedium>, language: BookLanguage?): ScannedBook =
        GraphQLClient.perform(
            ScanSeriesVolumeMutation(
                SeriesVolumeInput(
                    authors = listOf(author),
                    format = Optional.present(format.graphQL),
                    kind = membership.kind.graphQL,
                    language = language?.graphQL.present(),
                    media = if (format == BookFormat.AUDIOBOOK) Optional.Absent else Optional.present(media.map { it.graphQL }),
                    seriesId = membership.id,
                    seriesName = membership.name,
                    title = title,
                    volume = membership.volume.present(),
                ),
            ),
            changesLibrary = false,
        ).scanSeriesVolume.scannedRecord.asDomain

    suspend fun detect(jpeg: ByteArray): List<DetectedBook> =
        GraphQLClient.perform(DetectBooksMutation(base64(jpeg)), changesLibrary = false).detectBooks.mapIndexed { index, book ->
            DetectedBook(
                id = index,
                title = book.title,
                authors = book.authors,
                publisher = book.publisher,
                language = book.language?.asDomain,
                format = book.format?.asDomain,
                media = book.media.asDomain,
                seriesName = book.seriesName,
                volume = book.volume,
                box = NormalizedBox(book.box.x, book.box.y, book.box.width, book.box.height),
                owned = book.owned,
            )
        }

    suspend fun addDetected(book: DetectedBook): Book =
        GraphQLClient.perform(
            AddDetectedBookMutation(
                DetectedBookInput(
                    authors = book.authors,
                    format = book.format?.graphQL.present(),
                    language = book.language?.graphQL.present(),
                    media = if (book.media.isEmpty()) Optional.Absent else Optional.present(book.media.map { it.graphQL }),
                    publisher = book.publisher.present(),
                    seriesName = book.seriesName.present(),
                    title = book.title ?: "",
                    volume = book.volume.present(),
                ),
            ),
        ).addDetectedBook.bookDetail.asBook
}

val ScannedRecord.asDomain: ScannedBook
    get() = ScannedBook(
        recognized = recognized,
        title = title,
        authors = authors,
        format = format?.asDomain,
        media = media.asDomain,
        publisher = publisher,
        firstPublishedIn = firstPublishedIn,
        synopsis = synopsis,
        genre = genre?.asDomain,
        subgenres = subgenres,
        pageCount = pageCount,
        isbn13 = isbn13,
        language = language?.asDomain,
        coverURL = coverUrl,
        series = series?.let { SeriesMembership(it.id, it.name, it.volume, it.kind.asDomain) },
        ownedCopy = ownedCopy?.bookSummary?.asBook,
    )
