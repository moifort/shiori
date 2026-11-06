package com.polyforms.shiori.shared

import com.apollographql.apollo.ApolloClient
import com.apollographql.apollo.api.ApolloResponse
import com.apollographql.apollo.api.Mutation
import com.apollographql.apollo.api.Optional
import com.apollographql.apollo.api.Query
import com.apollographql.apollo.api.http.HttpRequest
import com.apollographql.apollo.api.http.HttpResponse
import com.apollographql.apollo.network.http.HttpInterceptor
import com.apollographql.apollo.network.http.HttpInterceptorChain
import com.apollographql.apollo.network.okHttpClient
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.polyforms.shiori.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/** The GraphQL endpoint: the deployed server, unless a debug build was pointed elsewhere. */
object ApiEndpoint {
    @Volatile var override: String? = null
    val baseURL: String get() = override ?: BuildConfig.SERVER_URL
}

/** What a request that came back refused says: the server's code, or its message. */
sealed class ApiError(message: String) : Exception(message) {
    class InvalidResponse : ApiError(L("Réponse invalide du serveur"))
    class Http(val code: Int) : ApiError(L("Erreur serveur (%lld)", code))
    class GraphQL(val messages: List<String>) : ApiError(messages.joinToString(" — "))

    /** A refusal the server named, e.g. `QUOTA_EXHAUSTED`. */
    class Domain(val code: String, val messages: List<String>) : ApiError(
        if (code == "AI_UNAVAILABLE") {
            L("L'IA de Shiori est momentanément indisponible. Rien n'a été décompté ; réessayez dans un moment.")
        } else {
            messages.joinToString(" — ")
        },
    )

    val domainCode: String? get() = (this as? Domain)?.code
}

/** What a single write changed, when it changed one thing. */
sealed interface DataChange {
    data class BookChange(val id: String) : DataChange
    data class SeriesChange(val id: String) : DataChange
}

/**
 * Something in the library changed on the server. Posted after every mutation that came back,
 * so a list left open on another tab redraws itself; `null` means anything may have moved.
 */
object DataChanges {
    private val flow = MutableSharedFlow<DataChange?>(extraBufferCapacity = 16)
    val notices: SharedFlow<DataChange?> get() = flow
    fun post(change: DataChange?) {
        flow.tryEmit(change)
    }
}

/** Sends the Firebase ID token; a refused one signs the reader out when the account is gone. */
private class FirebaseTokenInterceptor : HttpInterceptor {
    override suspend fun intercept(request: HttpRequest, chain: HttpInterceptorChain): HttpResponse {
        val builder = request.newBuilder()
        val user = if (FirebaseApp.getApps(AppContext.get()).isEmpty()) null else FirebaseAuth.getInstance().currentUser
        if (user != null) {
            val token = try {
                user.getIdToken(false).await().token
            } catch (error: Exception) {
                AuthEvents.accountMayBeGone()
                throw error
            }
            if (token != null) builder.addHeader("Authorization", "Bearer $token")
        }
        val response = chain.proceed(builder.build())
        if (response.statusCode == 401) AuthEvents.accountMayBeGone()
        return response
    }
}

/** The app's language, so the server writes AI results in it. */
private class AcceptLanguageInterceptor : HttpInterceptor {
    override suspend fun intercept(request: HttpRequest, chain: HttpInterceptorChain): HttpResponse =
        chain.proceed(request.newBuilder().addHeader("Accept-Language", Strings.appLanguage).build())
}

/** Hooks the auth layer listens to, so the network layer never imports a screen. */
object AuthEvents {
    @Volatile var onAccountMayBeGone: suspend () -> Unit = {}
    suspend fun accountMayBeGone() = onAccountMayBeGone()
}

object GraphQLClient {
    /** Built once: the base URL is read at first use, as on iOS. */
    val apollo: ApolloClient by lazy {
        ApolloClient.Builder()
            .serverUrl(ApiEndpoint.baseURL.trimEnd('/') + "/graphql")
            // A scan or a saga catalogued on its first opening keeps the server silent for long.
            .okHttpClient(
                OkHttpClient.Builder()
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(240, TimeUnit.SECONDS)
                    .writeTimeout(120, TimeUnit.SECONDS)
                    .build(),
            )
            .addHttpInterceptor(FirebaseTokenInterceptor())
            .addHttpInterceptor(AcceptLanguageInterceptor())
            .build()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val inFlight = mutableMapOf<Any, Deferred<Any>>()
    private val lock = Mutex()

    /**
     * A query, network only. The same query with the same variables, asked while one is on its
     * way, shares that request.
     */
    @Suppress("UNCHECKED_CAST")
    suspend fun <D : Query.Data> fetch(query: Query<D>): D {
        val key: Any = query
        val shared = lock.withLock {
            inFlight[key] ?: scope.async { unwrap(apollo.query(query).execute()) as Any }.also { deferred ->
                inFlight[key] = deferred
                deferred.invokeOnCompletion { scope.async { lock.withLock { inFlight.remove(key) } } }
            }
        }
        return shared.await() as D
    }

    /**
     * A mutation. `changesLibrary` false for a write that leaves the books as they were; `change`
     * names the one book or saga it changed, so an open list can patch that row.
     */
    suspend fun <D : Mutation.Data> perform(
        mutation: Mutation<D>,
        change: DataChange? = null,
        changesLibrary: Boolean = true,
    ): D {
        val data = unwrap(apollo.mutation(mutation).execute())
        if (changesLibrary) DataChanges.post(change)
        return data
    }

    private fun <D : com.apollographql.apollo.api.Operation.Data> unwrap(response: ApolloResponse<D>): D {
        val errors = response.errors
        if (!errors.isNullOrEmpty()) {
            val code = errors.firstNotNullOfOrNull { it.extensions?.get("code") as? String }
            val messages = errors.map { it.message }
            if (code != null) throw ApiError.Domain(code, messages)
            throw ApiError.GraphQL(messages)
        }
        response.exception?.let { throw it }
        return response.data ?: throw ApiError.InvalidResponse()
    }
}

/** An optional argument: blank strings are absent, never sent as `""`. */
fun String?.asOptional(): Optional<String?> =
    if (this.isNullOrBlank()) Optional.Absent else Optional.Present(this)

fun <T> T?.present(): Optional<T?> = Optional.presentIfNotNull(this)
