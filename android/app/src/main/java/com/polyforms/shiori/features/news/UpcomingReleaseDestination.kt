package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.DiscoverApi
import com.polyforms.shiori.features.discover.DiscoveryPage
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.narrators.NarratorDestination
import com.polyforms.shiori.shared.BookFormat

/**
 * What a release of "À venir" opens: a saga's next volume on its announced page, an edition
 * awaited on its page, an author's work on the author, a narrator's recording on the narrator.
 *
 * Never awaited before a push: a tap pushes `UpcomingReleaseScreen`, which looks the release up
 * behind its loader.
 */
sealed interface UpcomingReleaseDestination {
    data class Announced(val volume: DiscoveryVolume) : UpcomingReleaseDestination
    data class Awaited(val edition: AwaitedEdition) : UpcomingReleaseDestination
    data class Author(val author: AuthorDestination) : UpcomingReleaseDestination
    data class Narrator(val narrator: NarratorDestination) : UpcomingReleaseDestination

    /** What the release watches hold, looked up without any web search. */
    interface Lookup {
        suspend fun discovery(format: ReleaseFormat): DiscoveryPage
        suspend fun awaited(format: ReleaseFormat): List<AwaitedEdition>

        companion object {
            val live: Lookup = object : Lookup {
                override suspend fun discovery(format: ReleaseFormat) = DiscoverApi.discovery(format)
                override suspend fun awaited(format: ReleaseFormat) = AwaitedApi.awaited(format)
            }
        }
    }

    companion object {
        /**
         * What the release itself names, with nothing to fetch: an author's page, a narrator's.
         * Null for a volume or an edition, which the release watches hold.
         */
        fun immediate(release: UpcomingRelease): UpcomingReleaseDestination? = when (release.source) {
            ReleaseSource.SAGA, ReleaseSource.AWAITED -> null
            ReleaseSource.AUTHOR -> release.author?.let { Author(AuthorDestination(it.key, it.name)) }
            ReleaseSource.NARRATOR -> {
                // "narrator~<narrator key>~<title>".
                val parts = release.id.split("~")
                val name = release.narrator
                if (parts.size < 2 || name == null) null else Narrator(NarratorDestination(parts[1], name))
            }
        }

        /**
         * Looks the release up among what the release watches already hold. Null when the watch no
         * longer lists it; throws when the watch could not be read.
         */
        suspend fun of(release: UpcomingRelease, lookup: Lookup = Lookup.live): UpcomingReleaseDestination? {
            val format = if (release.format == BookFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK
            return when (release.source) {
                ReleaseSource.SAGA -> {
                    val row = lookup.discovery(format).rows.firstOrNull {
                        it.series.name == release.seriesName && it.releases.next?.number == release.volume &&
                            (release.language == null || it.series.language == release.language)
                    } ?: return null
                    val next = row.releases.next ?: return null
                    Announced(DiscoveryVolume(row, next))
                }
                ReleaseSource.AWAITED -> {
                    // "awaited~<edition id>", the server's id for a wait.
                    val id = release.id.removePrefix("awaited~")
                    lookup.awaited(format).firstOrNull { it.id == id }?.let(::Awaited)
                }
                ReleaseSource.AUTHOR, ReleaseSource.NARRATOR -> immediate(release)
            }
        }
    }
}
