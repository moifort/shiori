package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind

/** Under its cover: the day it comes or came out, or that it is announced. */
val DiscoveryVolume.caption: String get() = volume.date?.let(ReleaseDateText::short) ?: L("Annoncé")

/** The volume as every list and its page draw it, until its page described it: the server's, else rebuilt from the list. */
val DiscoveryVolume.release: Release
    get() {
        volume.release?.let { return it }
        val series = saga.series
        return Release.listed(
            key = "volume-${series.seriesId}-${volume.number}",
            title = volume.title,
            authors = listOfNotNull(series.author),
            releaseFormat = if (series.isAudio) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK,
            state = if (volume.date?.let(ReleaseDateText::isUpcoming) != false) AwaitedState.ANNOUNCED else AwaitedState.AVAILABLE,
            language = series.language,
            date = volume.date,
            isbn13 = volume.isbn13,
            coverURL = volume.coverURL,
            storeURL = volume.audibleURL,
            series = SeriesMembership(series.seriesId, series.name, volume.number, VolumeKind.MAIN),
        )
    }

/** Drawn as the Books tab draws a book, the headphones on a recording's cover: on its tile and on its page alike. */
val DiscoveryVolume.cover: Book get() = book(release)

/** The volume as its page draws it, until its page described it. */
val DiscoveryVolume.book: Book get() = book(release)

/** A release of this volume as drawn: the list's, or the server's answer once its page described it. */
fun DiscoveryVolume.book(of: Release): Book = of.book("release-${saga.series.id}-${volume.number}")

/**
 * What adding it to the pile sends: the page as shown, described or not, filed in its saga at its
 * number, under the description's genre else the saga's.
 */
fun DiscoveryVolume.draft(shown: Book): BookDraft = BookDraft(
    title = shown.title,
    authors = shown.authors,
    format = shown.format,
    media = if (shown.format == BookFormat.AUDIOBOOK) emptyList() else BookDraft(shown.title).media,
    genre = shown.genre ?: saga.series.genre,
    subgenres = shown.subgenres,
    synopsis = shown.synopsis,
    publisher = shown.publisher,
    firstPublishedIn = shown.firstPublishedIn,
    pageCount = shown.pageCount,
    isbn13 = shown.isbn13,
    language = saga.series.language,
    series = shown.series,
    coverURL = shown.coverURL,
    status = ReadingStatus.TO_READ,
)
