package com.polyforms.shiori.features.discover

import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.SeriesMembership
import kotlinx.serialization.Serializable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.scan.ScannedBook
import com.polyforms.shiori.features.scan.asDomain
import com.polyforms.shiori.graphql.DescribeReleaseMutation
import com.polyforms.shiori.graphql.type.ReleaseInput
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.asOptional
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.present
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** What the web says of a book to come: its record, and for a recording who reads it and how long. */
data class ReleaseDescription(val book: ScannedBook, val narrators: List<String>, val durationMinutes: Int?)

/** The book filled in from its description, its own fields kept where it has them. */
fun Book.described(description: ReleaseDescription?): Book {
    val base = if (format == BookFormat.AUDIOBOOK) copy(media = emptyList()) else this
    val found = description?.book ?: return base
    return base.copy(
        publisher = publisher ?: found.publisher,
        firstPublishedIn = firstPublishedIn ?: found.firstPublishedIn,
        synopsis = synopsis ?: found.synopsis,
        genre = genre ?: found.genre,
        subgenres = subgenres.ifEmpty { found.subgenres },
        pageCount = if (format != BookFormat.AUDIOBOOK) pageCount ?: found.pageCount else pageCount,
        isbn13 = if (format != BookFormat.AUDIOBOOK) isbn13 ?: found.isbn13 else isbn13,
        language = language ?: found.language,
        coverURL = coverURL ?: found.coverURL,
        series = series ?: found.series,
        narrators = narrators.ifEmpty { description.narrators },
        durationMinutes = durationMinutes ?: description.durationMinutes,
    )
}

/** The description request before releases were one record; goes with this file once Actu is ported. */
object SeedReleaseApi {
    suspend fun describe(seed: ReleaseSeed): ReleaseDescription {
        val membership = seed.series?.takeIf { it.id.isNotEmpty() }
        val answer = GraphQLClient.perform(
            DescribeReleaseMutation(
                ReleaseInput(
                    authors = seed.authors,
                    coverUrl = seed.coverURL.asOptional(),
                    format = seed.format.graphQL,
                    isbn13 = seed.isbn13.asOptional(),
                    language = seed.language?.graphQL.present(),
                    releasedOn = seed.releasedOn.asOptional(),
                    seriesId = membership?.id.asOptional(),
                    seriesName = membership?.name.asOptional(),
                    title = seed.title,
                    volume = membership?.volume.present(),
                ),
            ),
            changesLibrary = false,
        ).describeRelease
        return ReleaseDescription(answer.book.scannedRecord.asDomain, answer.narrators, answer.durationMinutes)
    }
}

/** What a release description is asked from: a title to come, its authors, its edition. */
data class ReleaseSeed(
    val title: String,
    val authors: List<String>,
    val format: BookFormat,
    val language: BookLanguage? = null,
    val series: SeriesMembership? = null,
    val isbn13: String? = null,
    val releasedOn: String? = null,
    val coverURL: String? = null,
)
