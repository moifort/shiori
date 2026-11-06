package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.features.friends.FriendPicks
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesMembership
import kotlinx.serialization.Serializable

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

/** The next volume announced that the reader does not hold, and whether the saga was looked up. */
@Serializable
data class SagaReleases(val watched: Boolean, val next: DiscoveredVolume?)

/** A saga the reader follows and what it has for them. */
@Serializable
data class SagaDiscovery(
    val series: FollowedSeries,
    val releases: SagaReleases,
    val missing: List<Int> = emptyList(),
    val recent: List<DiscoveredVolume> = emptyList(),
) {
    val id: String get() = series.id
}

/** A work of an author outside the sagas the reader holds. */
@Serializable
data class DiscoveredWork(
    val title: String,
    val date: String?,
    val isbn13: String?,
    val coverURL: String?,
    val audibleURL: String? = null,
    val seriesName: String?,
    val volume: Int?,
) {
    val id: String get() = title
}

/** What one author has for the reader in one format. */
@Serializable
data class AuthorReleases(val next: DiscoveredWork? = null, val recent: List<DiscoveredWork> = emptyList(), val awaited: List<AwaitedEdition> = emptyList()) {
    val isEmpty: Boolean get() = next == null && recent.isEmpty() && awaited.isEmpty()
}

/** A volume of a saga, with the saga it belongs to. */
@Serializable
data class DiscoveryVolume(val saga: SagaDiscovery, val volume: DiscoveredVolume) {
    val id: String get() = "${saga.id}-${volume.number}"
}

@Serializable
data class AuthorDiscovery(
    val author: FollowedAuthor,
    val next: DiscoveredWork?,
    val recent: List<DiscoveredWork>,
    val awaited: List<AwaitedEdition>,
    val sagas: List<SagaDiscovery> = emptyList(),
) {
    val id: String get() = author.id
    val isEmpty: Boolean get() = next == null && recent.isEmpty() && awaited.isEmpty() && sagas.isEmpty()
    val awaitedOut: List<AwaitedEdition> get() = awaited.filter { it.state == AwaitedState.AVAILABLE }
    val awaitedComing: List<AwaitedEdition> get() = awaited.filter { it.state == AwaitedState.ANNOUNCED }
    val sagaComing: List<DiscoveryVolume> get() = sagas.mapNotNull { s -> s.releases.next?.let { DiscoveryVolume(s, it) } }
    val sagaOut: List<DiscoveryVolume> get() = sagas.flatMap { s -> s.recent.map { DiscoveryVolume(s, it) } }

    val soonestComing: String?
        get() = (listOf(next?.date) + awaitedComing.map { it.date } + sagaComing.map { it.volume.date }).mapNotNull { it?.let(ReleaseDateText::lastDay) }.minOrNull()

    val newestOut: String?
        get() = (recent.map { it.date } + awaitedOut.map { it.date } + sagaOut.map { it.volume.date }).mapNotNull { it?.let(ReleaseDateText::lastDay) }.maxOrNull()
}

/** Which half of a news summary: what came out, or what is coming. */
enum class ReleaseSection { RECENT, UPCOMING }

/** One author's news across formats, as the Authors shelf of Découvrir lists it. */
data class AuthorNews(val parts: List<Part>) {
    data class Part(val format: ReleaseFormat, val row: AuthorDiscovery)

    init {
        require(parts.isNotEmpty()) { "an author on the shelf has a row in some format" }
    }

    val id: String get() = author.id
    val author: FollowedAuthor get() = parts[0].row.author
    private val rows: List<AuthorDiscovery> get() = parts.map { it.row }
    val hasComing: Boolean get() = rows.any { it.next != null || it.awaitedComing.isNotEmpty() || it.sagaComing.isNotEmpty() }
    val hasOut: Boolean get() = rows.any { it.recent.isNotEmpty() || it.awaitedOut.isNotEmpty() || it.sagaOut.isNotEmpty() }
    val soonestComing: String? get() = rows.mapNotNull { it.soonestComing }.minOrNull()
    val newestOut: String? get() = rows.mapNotNull { it.newestOut }.maxOrNull()

    fun works(section: ReleaseSection): List<Pair<DiscoveredWork, ReleaseFormat>> = parts.flatMap { part ->
        val works = if (section == ReleaseSection.RECENT) part.row.recent else listOfNotNull(part.row.next)
        works.map { it to part.format }
    }

    fun volumes(section: ReleaseSection): List<DiscoveryVolume> = rows.flatMap { if (section == ReleaseSection.RECENT) it.sagaOut else it.sagaComing }

    fun awaited(section: ReleaseSection): List<AwaitedEdition> = rows.flatMap { if (section == ReleaseSection.RECENT) it.awaitedOut else it.awaitedComing }
}

/** Everything Découvrir draws, kept as one snapshot. */
@Serializable
data class DiscoveryFeed(
    val rows: Map<ReleaseFormat, List<SagaDiscovery>> = emptyMap(),
    val authors: Map<ReleaseFormat, List<AuthorDiscovery>> = emptyMap(),
    val followed: Map<ReleaseFormat, Int> = emptyMap(),
    val picks: FriendPicks = FriendPicks(),
    val awaited: Map<ReleaseFormat, List<AwaitedEdition>> = emptyMap(),
)

data class DiscoveryPage(val rows: List<SagaDiscovery>, val authors: List<AuthorDiscovery>, val unwatched: Int, val followed: Int)
