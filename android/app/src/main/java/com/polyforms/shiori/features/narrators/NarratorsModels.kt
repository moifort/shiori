@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.narrators

import com.polyforms.shiori.features.authors.PersonFacts
import com.polyforms.shiori.features.authors.ShelvedPerson
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
    override val key: String,
    override val name: String,
    override val indexLetter: String,
    override val portraitURL: String? = null,
    val shelvedAt: Instant?,
    override val books: List<Book>,
    override val favorite: Boolean = false,
    override val surname: String? = null,
) : ShelvedPerson {
    override val id: String get() = key
    override val initials: String get() = personInitials(name)
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
