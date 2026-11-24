package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.graphql.AwardSectionsQuery
import com.polyforms.shiori.graphql.DismissAwardWinnerMutation
import com.polyforms.shiori.graphql.ReconsiderAwardWinnerMutation
import com.polyforms.shiori.graphql.fragment.AwardWinnerFields
import com.polyforms.shiori.graphql.type.AwaitedState as GAwaitedState
import com.polyforms.shiori.graphql.type.ReleaseFormat as GReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.asDomain
import kotlinx.serialization.Serializable

/** What a discovery's buttons decide on: a suggestion, an award winner. */
interface Discovery {
    val id: String
    /** The format it is listed in. */
    val format: ReleaseFormat
    /** The formats its edition may be awaited in. */
    val awaitableFormats: List<ReleaseFormat>
    /** The edition the reader awaits already in `format`, when they do. */
    val awaitedEditionId: String?
}

@Serializable
enum class LiteraryAward(val graphQLName: String) {
    HUGO("HUGO"), NEBULA("NEBULA"), LOCUS_SCIENCE_FICTION("LOCUS_SF"), LOCUS_FANTASY("LOCUS_FANTASY"),
    CLARKE("CLARKE"), WORLD_FANTASY("WORLD_FANTASY"), GONCOURT("GONCOURT");

    val displayName: String
        get() = when (this) {
            HUGO -> L("Prix Hugo")
            NEBULA -> L("Prix Nebula")
            LOCUS_SCIENCE_FICTION -> L("Prix Locus de la science-fiction")
            LOCUS_FANTASY -> L("Prix Locus de la fantasy")
            CLARKE -> L("Prix Arthur C. Clarke")
            WORLD_FANTASY -> L("World Fantasy Award")
            GONCOURT -> L("Prix Goncourt")
        }

    val shortName: String
        get() = when (this) {
            HUGO -> "Hugo"
            NEBULA -> "Nebula"
            LOCUS_SCIENCE_FICTION, LOCUS_FANTASY -> "Locus"
            CLARKE -> "Clarke"
            WORLD_FANTASY -> "World Fantasy"
            GONCOURT -> "Goncourt"
        }

    val stripName: String get() = if (this == WORLD_FANTASY) "WFA" else shortName

    companion object {
        fun of(name: String) = entries.firstOrNull { it.graphQLName == name }
    }
}

@Serializable
data class AwardMention(val award: LiteraryAward, val year: Int)

/**
 * A novel an award crowned, as its edition stands in one format and the language of the app: out,
 * announced, or not found — not found also while nobody awaited it, which `watched` tells apart.
 */
@Serializable
data class AwardWinner(
    override val id: String,
    override val format: ReleaseFormat,
    /** Newest first. */
    val mentions: List<AwardMention>,
    /** Its edition as every list and its page draw it. */
    val release: Release,
    override val awaitableFormats: List<ReleaseFormat>,
    override val awaitedEditionId: String?,
    /** The novel whatever its format, which "Pas intéressé" turns down. */
    val key: String? = null,
    /** Whether the reader holds the novel in any format. Null on a snapshot saved before it was sent. */
    val inLibrary: Boolean? = null,
) : Discovery {
    /** A winner known only by what a fixture says of it: nothing described yet. */
    constructor(
        id: String,
        format: ReleaseFormat,
        title: String,
        originalTitle: String,
        originalLanguage: BookLanguage?,
        authors: List<String>,
        mentions: List<AwardMention>,
        state: AwaitedState,
        watched: Boolean,
        date: String?,
        coverURL: String?,
        storeURL: String?,
        awaitableFormats: List<ReleaseFormat>,
        awaitedEditionId: String?,
        key: String? = null,
    ) : this(
        id,
        format,
        mentions,
        Release.listed(
            key = id,
            title = title,
            originalTitle = originalTitle,
            authors = authors,
            releaseFormat = format,
            originalLanguage = originalLanguage,
            state = state,
            watched = watched,
            date = date,
            coverURL = coverURL,
            storeURL = storeURL,
        ),
        awaitableFormats,
        awaitedEditionId,
        key,
    )

    /** Its title in the app's language once found, else the one it won under. */
    val title: String get() = release.title
    val originalTitle: String get() = release.originalTitle
    val originalLanguage: BookLanguage? get() = release.originalLanguage
    val authors: List<String> get() = release.authors
    val state: AwaitedState get() = release.state
    val watched: Boolean get() = release.watched
    val date: String? get() = release.date
    val coverURL: String? get() = release.coverURL
    val storeURL: String? get() = release.storeURL

    val caption: String get() = mentions.firstOrNull()?.let { "${it.award.stripName} ${it.year}" } ?: ""

    val stateLine: String
        get() = when (state) {
            AwaitedState.AVAILABLE -> L("Disponible")
            AwaitedState.ANNOUNCED -> date?.let(ReleaseDateText::coming) ?: L("Annoncé, sans date")
            AwaitedState.UNANNOUNCED -> if (format == ReleaseFormat.AUDIOBOOK) L("Pas encore en audio") else L("Non traduit")
        }

    val stateTint: SystemTint
        get() = when (state) {
            AwaitedState.AVAILABLE -> SystemTint.GREEN
            AwaitedState.ANNOUNCED -> SystemTint.ORANGE
            AwaitedState.UNANNOUNCED -> SystemTint.GRAY
        }

    val awardsLine: String get() = mentions.joinToString(" · ") { "${it.award.displayName} ${it.year}" }
    val mentionsLine: String get() = mentions.joinToString(" · ") { "${it.award.shortName} ${it.year}" }

    /** Drawn as the Books tab draws a book: on its tile and on its page alike. */
    val cover: Book get() = release.book("award-$id")

    val draft: BookDraft get() = BookDraft(title = originalTitle, authors = authors, format = BookFormat.BOOK, language = originalLanguage)

    val pileDraft: BookDraft
        get() {
            var d = draft
            if (state != AwaitedState.UNANNOUNCED) d = d.copy(title = title, language = null, coverURL = coverURL)
            val f = if (format == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else BookFormat.BOOK
            return d.copy(format = f, media = if (f == BookFormat.AUDIOBOOK) emptyList() else d.media, status = ReadingStatus.TO_READ)
        }
}

val List<AwardWinner>.latestFirst: List<AwardWinner> get() = sortedByDescending { it.mentions.firstOrNull()?.year ?: 0 }

@Serializable
data class AwardSection(val genre: BookGenre, val winners: List<AwardWinner>) {
    val id: String get() = genre.name
}

fun GAwaitedState.asAwaited(): AwaitedState = when (this) {
    GAwaitedState.AVAILABLE -> AwaitedState.AVAILABLE
    GAwaitedState.ANNOUNCED -> AwaitedState.ANNOUNCED
    else -> AwaitedState.UNANNOUNCED
}

fun GReleaseFormat.asRelease(): ReleaseFormat = if (this == GReleaseFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK

object AwardsApi {
    suspend fun dismiss(key: String) {
        GraphQLClient.perform(DismissAwardWinnerMutation(key), changesLibrary = false)
    }

    suspend fun reconsider(key: String) {
        GraphQLClient.perform(ReconsiderAwardWinnerMutation(key), changesLibrary = false)
    }

    suspend fun sections(format: ReleaseFormat): List<AwardSection> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(AwardSectionsQuery(format.graphQL)).awardSections.map { it.awardSectionFields }.map { section ->
            AwardSection(section.genre.asDomain, section.winners.map { it.awardWinnerFields.asDomain }.latestFirst)
        }
    }
}

val AwardWinnerFields.asDomain: AwardWinner
    get() = AwardWinner(
        id = id,
        format = format.asRelease(),
        mentions = awards.mapNotNull { m -> LiteraryAward.of(m.award.rawValue)?.let { AwardMention(it, m.year) } },
        release = release.releaseFields.asRelease,
        awaitableFormats = awaitableFormats.mapNotNull(ReleaseFormat::of),
        awaitedEditionId = awaitedEditionId,
        key = key,
        inLibrary = inLibrary,
    )
