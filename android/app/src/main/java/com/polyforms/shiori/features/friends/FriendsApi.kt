package com.polyforms.shiori.features.friends

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.series.asSeries
import com.polyforms.shiori.graphql.AcceptFriendInvitationMutation
import com.polyforms.shiori.graphql.AddFriendBookMutation
import com.polyforms.shiori.graphql.FriendBookAudioQuery
import com.polyforms.shiori.graphql.FriendBookQuery
import com.polyforms.shiori.graphql.FriendLibraryPageQuery
import com.polyforms.shiori.graphql.FriendProfileQuery
import com.polyforms.shiori.graphql.FriendRecommendationsQuery
import com.polyforms.shiori.graphql.FriendSagaPageQuery
import com.polyforms.shiori.graphql.FriendSeriesScreenQuery
import com.polyforms.shiori.graphql.FriendsQuery
import com.polyforms.shiori.graphql.InviteFriendMutation
import com.polyforms.shiori.graphql.MyShelfQuery
import com.polyforms.shiori.graphql.RemoveFriendMutation
import com.polyforms.shiori.graphql.fragment.FriendBookRow
import com.polyforms.shiori.graphql.fragment.FriendRow
import com.polyforms.shiori.graphql.fragment.FriendSagaRow
import com.polyforms.shiori.graphql.fragment.SharedShelf
import com.polyforms.shiori.graphql.type.FriendActivityKind
import com.polyforms.shiori.graphql.type.AudioAvailability as GAudio
import com.polyforms.shiori.graphql.type.CopiedStatus as GCopied
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookSeries
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.parseISO8601
import java.time.Instant
import com.polyforms.shiori.graphql.type.SeriesState as GSeriesState

object FriendsApi {
    suspend fun friends(): List<Friend> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(FriendsQuery()).friends.map { it.friendRow.asDomain }
    }

    suspend fun profile(userId: String): FriendProfile? = GraphQLClient.fetch(FriendProfileQuery(userId)).friendProfile?.sharedShelf?.asDomain

    suspend fun myShelf(): FriendProfile = GraphQLClient.fetch(MyShelfQuery()).myShelf.sharedShelf.asDomain

    suspend fun libraryPage(friendId: String, status: ReadingStatus?, loved: Boolean = false, after: String?): Pair<List<FriendBook>, Boolean> {
        val page = GraphQLClient.fetch(
            FriendLibraryPageQuery(friendId, Optional.presentIfNotNull(status?.graphQL), if (loved) Optional.present(true) else Optional.Absent, Optional.presentIfNotNull(after)),
        ).friendLibraryPage ?: return emptyList<FriendBook>() to false
        return page.books.map { it.friendBookRow.asDomain } to page.hasMore
    }

    suspend fun sagaPage(friendId: String, state: SeriesState?, loved: Boolean, after: String?): Pair<List<FriendSaga>, Boolean> {
        val page = GraphQLClient.fetch(
            FriendSagaPageQuery(
                friendId,
                Optional.presentIfNotNull(state?.let { GSeriesState.safeValueOf(it.name) }),
                if (loved) Optional.present(true) else Optional.Absent,
                Optional.presentIfNotNull(after),
            ),
        ).friendSagaPage ?: return emptyList<FriendSaga>() to false
        return page.sagas.map { it.friendSagaRow.asDomain } to page.hasMore
    }

    suspend fun sagaScreen(friendId: String, seriesId: String): Pair<BookSeries?, FriendSaga?> {
        val data = GraphQLClient.fetch(FriendSeriesScreenQuery(friendId, seriesId))
        return data.series?.seriesCatalogue?.asSeries to data.friendSaga?.friendSagaRow?.asDomain
    }

    suspend fun picks(): FriendPicks {
        if (Showcase.isOn) return FriendPicks()
        val found = GraphQLClient.fetch(FriendRecommendationsQuery()).friendRecommendations.friendRecommendationsFields
        fun lovers(friends: List<Pair<String, String?>>, many: Boolean) = FriendLovers(friends.map { FriendLovers.Lover(it.first, it.second) }, many)
        return FriendPicks(
            books = found.books.map { row ->
                val l = row.friendLovedBookLovers
                LovedBook(row.book.friendBookRow.asDomain, lovers(l.friends.map { it.userId to it.firstName }, l.lovedByMany))
            },
            sagas = found.sagas.map { row ->
                val l = row.friendLovedSagaLovers
                LovedSaga(row.saga.friendSagaRow.asDomain, lovers(l.friends.map { it.userId to it.firstName }, l.lovedByMany))
            },
            authors = found.authors.map { row ->
                val l = row.friendLovedAuthorLovers
                LovedAuthor(row.author.key, row.author.name, row.author.portraitUrl, lovers(l.friends.map { it.userId to it.firstName }, l.lovedByMany))
            },
        )
    }

    suspend fun audio(friendId: String, bookId: String): AudioAvailability? =
        when (GraphQLClient.fetch(FriendBookAudioQuery(friendId, bookId)).friendBookAudio) {
            null -> null
            GAudio.AVAILABLE -> AudioAvailability.AVAILABLE
            GAudio.UNAVAILABLE -> AudioAvailability.UNAVAILABLE
            else -> AudioAvailability.UNKNOWN
        }

    suspend fun book(friendId: String, bookId: String): FriendBook? {
        val row = GraphQLClient.fetch(FriendBookQuery(friendId, bookId)).friendBook ?: return null
        val base = row.friendBookRow.asDomain
        return base.copy(
            book = base.book.copy(
                publisher = row.publisher,
                firstPublishedIn = row.firstPublishedIn,
                synopsis = row.synopsis,
                pageCount = row.pageCount,
                durationMinutes = row.durationMinutes,
                narrators = row.narrators,
                narratorKeys = row.narratorKeys,
                isbn13 = row.isbn13,
                note = row.note,
                authorKeys = row.authorKeys,
                audibleURL = row.audibleUrl,
                amazonURL = row.amazonUrl,
                addedAt = parseISO8601(row.addedAt),
                startedAt = parseISO8601(row.startedAt),
            ),
            ownerAvatarHero = row.ownerAvatarHero?.rawValue,
            ownerAvatarColor = row.ownerAvatarColor?.rawValue,
        )
    }

    suspend fun addBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat): String =
        GraphQLClient.perform(
            AddFriendBookMutation(friendId, bookId, if (status == CopiedStatus.READ) GCopied.READ else GCopied.TO_READ, Optional.present(format.graphQL)),
        ).addFriendBook.id

    suspend fun invite(): FriendInvitation {
        val data = GraphQLClient.perform(InviteFriendMutation(), changesLibrary = false).inviteFriend
        return FriendInvitation(data.code, parseISO8601(data.expiresAt) ?: Instant.now())
    }

    suspend fun accept(code: String): Friend = GraphQLClient.perform(AcceptFriendInvitationMutation(code), changesLibrary = false).acceptFriendInvitation.friendRow.asDomain

    suspend fun remove(userId: String): Boolean = GraphQLClient.perform(RemoveFriendMutation(userId), changesLibrary = false).removeFriend
}

val FriendRow.asDomain: Friend
    get() = Friend(
        userId = userId,
        firstName = firstName,
        since = parseISO8601(since) ?: Instant.now(),
        bookCount = bookCount,
        favoriteCount = favoriteCount,
        readingCount = readingCount,
        toReadCount = toReadCount,
        readThisYear = readThisYear,
        recentActivity = recentActivity.mapNotNull { row ->
            val at = parseISO8601(row.at) ?: return@mapNotNull null
            val (kind, status) = when (row.kind) {
                FriendActivityKind.READING -> RecentActivity.Kind.READING to ReadingStatus.READING
                FriendActivityKind.READ -> RecentActivity.Kind.FINISHED to ReadingStatus.READ
                FriendActivityKind.DROPPED -> RecentActivity.Kind.DROPPED to ReadingStatus.DROPPED
                FriendActivityKind.HEARTED -> RecentActivity.Kind.HEARTED to ReadingStatus.TO_READ
                FriendActivityKind.ADDED -> RecentActivity.Kind.ADDED to ReadingStatus.TO_READ
                else -> return@mapNotNull null
            }
            RecentActivity(
                kind,
                FriendBook(Book(id = row.bookId, title = row.title, authors = emptyList(), format = row.format.asDomain, coverURL = row.coverUrl, status = status), false),
                at,
            )
        },
    )

val SharedShelf.asDomain: FriendProfile
    get() = FriendProfile(
        userId = userId,
        firstName = firstName,
        reading = reading.map { it.friendBookRow.asDomain },
        pile = pile.map { it.friendBookRow.asDomain },
        favorites = favorites.map { it.friendBookRow.asDomain },
        sagas = sagas.map { it.friendSagaRow.asDomain },
        lastFinished = lastFinished?.friendBookRow?.asDomain,
        lastDropped = lastDropped?.friendBookRow?.asDomain,
        lastAdded = lastAdded?.friendBookRow?.asDomain,
        bookCount = bookCount,
        readThisYear = readThisYear,
    )

val FriendSagaRow.asDomain: FriendSaga
    get() = FriendSaga(
        id = id,
        seriesId = seriesId,
        name = name,
        isAudio = audio,
        author = author,
        language = language?.asDomain,
        ownedCount = ownedCount,
        favorite = favorite,
        favoritedAt = parseISO8601(favoritedAt),
        rating = rating,
        genre = genre?.asDomain,
        subgenre = subgenre,
        volumes = volumes.map { it.friendBookRow.asBook },
        lastActivityAt = volumes.mapNotNull { parseISO8601(it.friendBookRow.lastActivityAt) }.maxOrNull(),
        inLibrary = volumes.any { it.friendBookRow.inLibrary },
        shelvedAt = parseISO8601(shelvedAt),
        state = state.asDomain,
    )

val FriendBookRow.asDomain: FriendBook
    get() = FriendBook(asBook, inLibrary, parseISO8601(favoritedAt), parseISO8601(lastActivityAt))

val FriendBookRow.asBook: Book
    get() = Book(
        id = id,
        title = title,
        authors = authors,
        format = format.asDomain,
        genre = genre?.asDomain,
        subgenres = subgenres,
        listeningProgress = listeningProgress?.toInt(),
        language = language?.asDomain,
        series = series?.let { SeriesMembership(it.id, it.name, it.volume, it.kind.asDomain) },
        coverURL = coverUrl,
        status = status.asDomain,
        rating = rating,
        favorite = favorite,
        addedAt = parseISO8601(addedAt),
        startedAt = parseISO8601(startedAt),
        finishedAt = parseISO8601(finishedAt),
        shelvedAt = parseISO8601(shelvedAt),
    )
