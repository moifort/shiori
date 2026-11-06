@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.narrators

import com.polyforms.shiori.features.authors.PersonFacts
import com.polyforms.shiori.features.authors.personInitials
import com.polyforms.shiori.features.series.cardCoverURL
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.InstantSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

@Serializable
data class FollowedNarrator(
    val key: String,
    val name: String,
    val indexLetter: String,
    val portraitURL: String? = null,
    val shelvedAt: Instant?,
    val books: List<Book>,
    val favorite: Boolean = false,
    val surname: String? = null,
) {
    val id: String get() = key
    val initials: String get() = personInitials(name)
}

@Serializable
data class NarratorRow(val key: String, val name: String, val portraitURL: String? = null) {
    val id: String get() = key
    val initials: String get() = personInitials(name)
}

data class NarratorDestination(val key: String, val name: String)

@Serializable
data class NarratorPage(
    val key: String,
    val name: String,
    val portraitURL: String?,
    val favorite: Boolean,
    val bookCount: Int,
    val readCount: Int,
    val seriesCount: Int,
    val averageRating: Double?,
    val sagas: List<FollowedSeries>,
    val books: List<Book>,
    val nationality: String? = null,
    val birthYear: Int? = null,
    val deathYear: Int? = null,
    val biography: String? = null,
    val isAwaitingCatalogue: Boolean = false,
) {
    val initials: String get() = personInitials(name)
    val facts: PersonFacts get() = PersonFacts(nationality, birthYear, deathYear, biography)
    val backdropURL: String? get() = (sagas.map { it.cardCoverURL } + books.map { it.coverURL }).firstOrNull { it != null } ?: portraitURL
}
