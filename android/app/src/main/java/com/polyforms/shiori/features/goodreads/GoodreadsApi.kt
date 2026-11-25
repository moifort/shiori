package com.polyforms.shiori.features.goodreads

import com.polyforms.shiori.graphql.GoodreadsImportQuery
import com.polyforms.shiori.graphql.ImportGoodreadsExportMutation
import com.polyforms.shiori.graphql.PreviewGoodreadsExportMutation
import com.polyforms.shiori.graphql.SeekGoodreadsCoversMutation
import com.polyforms.shiori.graphql.fragment.GoodreadsRowFields
import com.polyforms.shiori.graphql.type.GoodreadsChoicesInput
import com.polyforms.shiori.graphql.type.GoodreadsToRead
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.parseISO8601
import com.polyforms.shiori.graphql.type.GoodreadsShelf as GShelf
import com.polyforms.shiori.graphql.type.GoodreadsVerdict as GVerdict

/** The Goodreads import, as the app talks to it: generated types never leave this file. */
object GoodreadsApi {
    /** What the file holds, against the library. Saves nothing. */
    suspend fun preview(csv: String): GoodreadsPreview {
        val data = try {
            GraphQLClient.perform(PreviewGoodreadsExportMutation(csv), changesLibrary = false).previewGoodreadsExport
        } catch (error: ApiError) {
            when (error.domainCode) {
                "GOODREADS_NOT_AN_EXPORT" -> throw GoodreadsFileError(GoodreadsFileError.Kind.NOT_GOODREADS)
                "GOODREADS_EMPTY_EXPORT" -> throw GoodreadsFileError(GoodreadsFileError.Kind.EMPTY)
                else -> throw error
            }
        }
        return GoodreadsPreview(
            rows = data.rows.map { it.goodreadsRowFields.asDomain },
            readCount = data.shelves.read,
            readingCount = data.shelves.reading,
            toReadCount = data.shelves.toRead,
            droppedCount = data.shelves.dropped,
            ratedCount = data.rated,
            datedCount = data.dated,
            reviewedCount = data.reviewed,
        )
    }

    /** Writes the ticked rows from a second read of the same file. */
    suspend fun importExport(csv: String, choices: GoodreadsChoices): GoodreadsImportOutcome {
        val input = GoodreadsChoicesInput(
            keys = choices.keys.sorted(),
            toRead = if (choices.toRead == GoodreadsChoices.ToRead.PILE) GoodreadsToRead.PILE else GoodreadsToRead.WISHLIST,
            keepRatings = choices.keepRatings,
            keepDates = choices.keepDates,
            keepReviews = choices.keepReviews,
            sameBooks = choices.sameBooks.sorted(),
        )
        val outcome = GraphQLClient.perform(ImportGoodreadsExportMutation(csv, input)).importGoodreadsExport
        return GoodreadsImportOutcome(outcome.imported, outcome.completed, outcome.wished, outcome.pendingCovers)
    }

    /** One pass of the cover search: how many were found, how many are left. */
    suspend fun seekCovers(): Pair<Int, Int> {
        val pass = GraphQLClient.perform(SeekGoodreadsCoversMutation()).seekGoodreadsCovers
        return pass.found to pass.remaining
    }

    /** The last import, null when the reader never imported. */
    suspend fun lastImport(): GoodreadsImportSummary? =
        GraphQLClient.fetch(GoodreadsImportQuery()).goodreadsImport?.let {
            GoodreadsImportSummary(parseISO8601(it.importedAt), it.imported, it.completed, it.wished, it.pendingCovers, it.withoutCover)
        }
}

private val GoodreadsRowFields.asDomain: GoodreadsRow
    get() = GoodreadsRow(
        key = key,
        title = title,
        authors = authors,
        seriesName = series?.name,
        volume = series?.volume,
        format = format.asDomain,
        media = media.asDomain,
        language = language?.asDomain,
        rating = rating,
        readOn = parseISO8601(readOn),
        shelf = when (shelf) {
            GShelf.READ -> GoodreadsShelf.READ
            GShelf.CURRENTLY_READING -> GoodreadsShelf.CURRENTLY_READING
            else -> GoodreadsShelf.TO_READ
        },
        dropped = dropped,
        hasReview = hasReview,
        verdict = when (verdict) {
            GVerdict.HELD -> GoodreadsVerdict.HELD
            GVerdict.UNCERTAIN -> GoodreadsVerdict.UNCERTAIN
            else -> GoodreadsVerdict.NEW
        },
        heldBookId = heldBookId,
        heldTitle = heldTitle,
        heldCoverURL = heldCoverUrl,
        coverURL = coverUrl,
    )

