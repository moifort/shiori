package com.polyforms.shiori.features.settings

import com.polyforms.shiori.graphql.ChangelogQuery
import com.polyforms.shiori.graphql.DeleteAccountMutation
import com.polyforms.shiori.graphql.NotificationSettingsQuery
import com.polyforms.shiori.graphql.RegisterDeviceMutation
import com.polyforms.shiori.graphql.SetAlertMutation
import com.polyforms.shiori.graphql.UnregisterDeviceMutation
import com.polyforms.shiori.graphql.fragment.NotificationSettingsFields
import com.polyforms.shiori.graphql.type.PushEnvironment
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.parseISO8601
import java.time.Instant
import com.polyforms.shiori.graphql.type.AlertKind as GAlertKind

data class ChangelogEntry(val version: String, val date: Instant?, val notes: List<String>) {
    val id: String get() = version
}

/** The alerts a reader can switch on or off. */
enum class AlertKind {
    TRANSLATION, DIGEST, DISCOVERIES;

    val title: String
        get() = when (this) {
            TRANSLATION -> L("Nouvelle sortie")
            DIGEST -> L("Nouveauté hebdomadaire")
            DISCOVERIES -> L("Découvertes du mois")
        }

    val symbol: String
        get() = when (this) {
            TRANSLATION -> "book.closed"
            DIGEST -> "calendar"
            DISCOVERIES -> "sparkles"
        }

    val graphQL: GAlertKind get() = GAlertKind.safeValueOf(name)
}

data class NotificationSettings(val enabled: Set<AlertKind>, val deviceCount: Int)

object SettingsApi {
    suspend fun changelog(): List<ChangelogEntry> =
        GraphQLClient.fetch(ChangelogQuery()).changelog.map { ChangelogEntry(it.version, parseISO8601(it.date), it.notes) }

    suspend fun deleteAccount() {
        GraphQLClient.perform(DeleteAccountMutation(), changesLibrary = false)
    }
}

object NotificationsApi {
    suspend fun settings(): NotificationSettings = GraphQLClient.fetch(NotificationSettingsQuery()).notificationSettings.notificationSettingsFields.asDomain

    suspend fun setAlert(kind: AlertKind, enabled: Boolean): NotificationSettings =
        GraphQLClient.perform(SetAlertMutation(kind.graphQL, enabled), changesLibrary = false).setAlert.notificationSettingsFields.asDomain

    /** An Android phone registers its FCM token under the FCM environment. */
    suspend fun registerDevice(token: String) {
        GraphQLClient.perform(RegisterDeviceMutation(token = token, environment = PushEnvironment.FCM), changesLibrary = false)
    }

    suspend fun unregisterDevice(token: String) {
        GraphQLClient.perform(UnregisterDeviceMutation(token), changesLibrary = false)
    }
}

private val NotificationSettingsFields.asDomain: NotificationSettings
    get() = NotificationSettings(
        enabled = alerts.filter { it.enabled }.mapNotNull { a -> AlertKind.entries.firstOrNull { it.name == a.kind.rawValue } }.toSet(),
        deviceCount = deviceCount,
    )
