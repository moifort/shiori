package com.polyforms.shiori.shared

import com.polyforms.shiori.graphql.fragment.BookDetail
import com.polyforms.shiori.graphql.fragment.BookSummary
import com.polyforms.shiori.graphql.fragment.SeriesOpinionFields
import com.polyforms.shiori.graphql.fragment.VolumeEntry
import com.polyforms.shiori.graphql.type.BookFormat as GBookFormat
import com.polyforms.shiori.graphql.type.BookLanguage as GBookLanguage
import com.polyforms.shiori.graphql.type.BookMedium as GBookMedium
import com.polyforms.shiori.graphql.type.Genre as GGenre
import com.polyforms.shiori.graphql.type.ReadingStatus as GReadingStatus
import com.polyforms.shiori.graphql.type.SeriesState as GSeriesState
import com.polyforms.shiori.graphql.type.VolumeKind as GVolumeKind

/*
 * Mapping from the generated GraphQL types to the domain model, in one file. Unknown cases map
 * to the safest neighbour rather than crashing: the schema is not versioned, so a client can
 * meet a value added after it shipped. Domain enums carry the schema's own names.
 */

/** An unrecognized status reads as "to read": the only state true of every book. */
val GReadingStatus.asDomain: ReadingStatus
    get() = ReadingStatus.entries.firstOrNull { it.name == name } ?: ReadingStatus.TO_READ

/** An unrecognized format reads as a plain book; the deprecated EBOOK is a book. */
val GBookFormat.asDomain: BookFormat
    get() = BookFormat.entries.firstOrNull { it.name == name } ?: BookFormat.BOOK

/** A medium added after this build shipped is left out rather than guessed. */
val List<GBookMedium>.asDomain: List<BookMedium>
    get() = mapNotNull { m -> BookMedium.entries.firstOrNull { it.name == m.name } }

/** An unrecognized genre reads as "other". */
val GGenre.asDomain: BookGenre
    get() = BookGenre.entries.firstOrNull { it.name == name } ?: BookGenre.OTHER

/** An unrecognized language reads as none at all. */
val GBookLanguage.asDomain: BookLanguage?
    get() = BookLanguage.entries.firstOrNull { it.name == name }

/** An unrecognized kind lands in the related works rather than the spine. */
val GVolumeKind.asDomain: VolumeKind
    get() = VolumeKind.entries.firstOrNull { it.name == name } ?: VolumeKind.COMPANION

val GSeriesState.asDomain: SeriesState
    get() = SeriesState.entries.firstOrNull { it.name == name } ?: SeriesState.IN_PROGRESS

val ReadingStatus.graphQL: GReadingStatus get() = GReadingStatus.safeValueOf(name)
val BookFormat.graphQL: GBookFormat get() = GBookFormat.safeValueOf(name)
val BookMedium.graphQL: GBookMedium get() = GBookMedium.safeValueOf(name)
val BookGenre.graphQL: GGenre get() = GGenre.safeValueOf(name)
val BookLanguage.graphQL: GBookLanguage get() = GBookLanguage.safeValueOf(name)
val VolumeKind.graphQL: GVolumeKind get() = GVolumeKind.safeValueOf(name)

val BookSummary.asBook: Book
    get() = Book(
        id = id,
        title = title,
        authors = authors,
        authorKeys = authorKeys,
        format = format.asDomain,
        media = media.asDomain,
        genre = genre?.asDomain,
        subgenres = subgenres,
        listeningProgress = listeningProgress?.toInt(),
        language = language?.asDomain,
        series = series?.let { SeriesMembership(it.id, it.name, it.volume, it.kind.asDomain, it.annexNumber) },
        coverURL = coverUrl,
        status = status.asDomain,
        rating = rating,
        seriesRating = seriesRating,
        favorite = favorite,
        shelvedAt = parseISO8601(shelvedAt),
        statusChangedAt = parseISO8601(statusChangedAt),
    )

val BookDetail.asBook: Book
    get() = Book(
        id = id,
        title = title,
        authors = authors,
        authorKeys = authorKeys,
        format = format.asDomain,
        media = media.asDomain,
        publisher = publisher,
        firstPublishedIn = firstPublishedIn,
        editionYear = editionYear,
        synopsis = synopsis,
        genre = genre?.asDomain,
        subgenres = subgenres,
        pageCount = pageCount,
        currentPage = currentPage,
        durationMinutes = durationMinutes,
        narrators = narrators,
        narratorKeys = narratorKeys,
        listeningProgress = listeningProgress?.toInt(),
        audibleURL = audibleUrl,
        amazonURL = amazonUrl,
        isbn13 = isbn13,
        language = language?.asDomain,
        series = series?.let { SeriesMembership(it.id, it.name, it.volume, it.kind.asDomain, it.annexNumber) },
        forthcoming = forthcoming,
        coverURL = coverUrl,
        status = status.asDomain,
        rating = rating,
        seriesRating = seriesRating,
        favorite = favorite,
        note = note,
        recommendation = recommendation?.let { BookRecommendation(it.recommenderName, it.comment) },
        hidden = hidden,
        awaitingDescription = awaitingDescription,
        addedAt = parseISO8601(addedAt),
        startedAt = parseISO8601(startedAt),
        finishedAt = parseISO8601(finishedAt),
    )

val VolumeEntry.asVolume: Volume
    get() = Volume(
        number = number,
        title = title,
        publishedIn = publishedIn,
        kind = kind.asDomain,
        releases = releases.mapNotNull { release ->
            val language = release.language.asDomain ?: return@mapNotNull null
            VolumeRelease(language, release.date, release.title, release.coverUrl)
        },
    )

val SeriesOpinionFields.asOpinion: SeriesOpinion
    get() = SeriesOpinion(
        seriesId = seriesId,
        rating = rating,
        favorite = favorite,
        volumeCount = volumeCount,
        followed = followed,
        unfollowedLanguages = unfollowedLanguages.mapNotNull { it.asDomain },
    )
