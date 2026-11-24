package com.polyforms.shiori.features.news

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.asDomain
import com.polyforms.shiori.features.discover.latestFirst
import com.polyforms.shiori.graphql.NarratorNewsQuery
import com.polyforms.shiori.graphql.NewsFeedQuery
import com.polyforms.shiori.graphql.NewsOpeningQuery
import com.polyforms.shiori.graphql.WishlistReleasesQuery
import com.polyforms.shiori.graphql.fragment.NarratorNewsFields
import com.polyforms.shiori.graphql.fragment.NewsFeedPage
import com.polyforms.shiori.graphql.UpcomingReleasesQuery
import com.polyforms.shiori.graphql.YearReleasesQuery
import com.polyforms.shiori.graphql.fragment.UpcomingReleaseFields
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.account.AvatarHero
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.parseISO8601

object NewsApi {
    /** One page of what the friends did, newest first. */
    suspend fun feed(after: String?, limit: Int): CursorPage<FeedEvent> {
        if (Showcase.isOn) return CursorPage(emptyList(), false, null)
        return page(GraphQLClient.fetch(NewsFeedQuery(limit, Optional.presentIfNotNull(after))).newsFeed.newsFeedPage)
    }

    /**
     * The tab's opening in one request: the friends' first page and every section beside it, so
     * the server reads the library once for all.
     */
    suspend fun opening(limit: Int): NewsOpening {
        if (Showcase.isOn) return NewsOpening(CursorPage(emptyList(), false, null), emptyList(), emptyList(), emptyList(), emptyList(), emptyList())
        val data = GraphQLClient.fetch(NewsOpeningQuery(limit))
        return NewsOpening(
            feed = page(data.newsFeed.newsFeedPage),
            upcoming = data.upcomingReleases.mapNotNull { it.upcomingReleaseFields.asDomain },
            yearReleases = data.yearReleases.mapNotNull { it.upcomingReleaseFields.asDomain },
            narratorNews = data.narratorNews.map { it.narratorNewsFields.asNews },
            awards = data.awardSections.map { it.awardSectionFields }.map { section ->
                AwardSection(section.genre.asDomain, section.winners.map { it.awardWinnerFields.asDomain }.latestFirst)
            },
            discoveries = data.monthlyDiscoveries.monthlyDiscoveriesFields.suggestions.map { it.suggestionFields.asDomain },
            wishlistReleases = data.wishlistReleases.mapNotNull { it.upcomingReleaseFields.asDomain },
        )
    }

    /** What the wish list rail shows: to come, out lately, then out already when asked for lately. */
    suspend fun wishlistReleases(): List<UpcomingRelease> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(WishlistReleasesQuery()).wishlistReleases.mapNotNull { it.upcomingReleaseFields.asDomain }
    }

    private fun page(page: NewsFeedPage): CursorPage<FeedEvent> {
        val events = page.events.mapNotNull { row ->
            val kind = FeedEventKind.entries.firstOrNull { it.name == row.kind.rawValue } ?: return@mapNotNull null
            val at = parseISO8601(row.at) ?: return@mapNotNull null
            FeedEvent(
                id = row.id,
                kind = kind,
                at = at,
                friendId = row.friendId,
                friendName = row.friendFirstName ?: "",
                avatarHero = row.friendAvatarHero?.let { AvatarHero.ofGraphQL(it.rawValue) },
                avatarColor = row.friendAvatarColor?.let { c -> AvatarColor.entries.firstOrNull { it.name == c.rawValue } },
                bookId = row.bookId,
                title = row.title,
                authors = row.authors,
                format = row.format.asDomain,
                language = row.language?.asDomain,
                coverURL = row.coverUrl,
                rating = row.rating,
                alsoStartedBy = row.alsoStartedBy,
                inLibrary = row.inLibrary,
            )
        }
        return CursorPage(events, page.nextCursor != null, page.nextCursor)
    }

    suspend fun narratorNews(): List<NarratorNews> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(NarratorNewsQuery()).narratorNews.map { it.narratorNewsFields.asNews }
    }

    suspend fun upcoming(): List<UpcomingRelease> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(UpcomingReleasesQuery()).upcomingReleases.mapNotNull { it.upcomingReleaseFields.asDomain }
    }

    suspend fun yearReleases(): List<UpcomingRelease> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(YearReleasesQuery()).yearReleases.mapNotNull { it.upcomingReleaseFields.asDomain }
    }
}

private val NarratorNewsFields.asNews: NarratorNews
    get() = NarratorNews(id, narratorKey, narrator, title, authors, date, coverUrl, BookFormat.AUDIOBOOK, language?.asDomain)

val UpcomingReleaseFields.asDomain: UpcomingRelease?
    get() {
        val source = ReleaseSource.entries.firstOrNull { it.name == source.rawValue } ?: return null
        return UpcomingRelease(
            id = id,
            source = source,
            format = format.asDomain,
            title = title,
            authors = authors,
            date = date,
            coverURL = coverUrl,
            seriesName = series?.name,
            volume = series?.volume,
            author = author?.let { UpcomingRelease.AuthorRef(it.key, it.name, it.favorite, it.portraitUrl) },
            sagaRating = sagaRating,
            sagaFavorite = sagaFavorite,
            narrator = narrator,
            language = language?.asDomain,
        )
    }
