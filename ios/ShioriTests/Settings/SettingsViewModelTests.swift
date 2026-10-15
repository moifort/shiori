import Foundation
import Testing
@testable import Shiori

@MainActor
struct NotificationSettingsViewModelTests {
    @Test func switchingOnAsksPermissionThenTheServer() async {
        let calls = Calls()
        var client = SettingsClient.preview
        client.requestNotificationPermission = { calls.record("permission") }
        client.setAlert = { kind, enabled in
            calls.record("\(kind)-\(enabled)")
            return NotificationSettings(enabled: [.translation, .digest], deviceCount: 1)
        }
        let viewModel = NotificationSettingsViewModel(client: client)
        await viewModel.load()

        await viewModel.set([.digest], enabled: true)

        #expect(calls.all == ["permission", "digest-true"])
        #expect(viewModel.settings?.enabled == [.translation, .digest])
    }

    @Test func refusedSwitchGoesBack() async {
        var client = SettingsClient.preview
        client.setAlert = { _, _ in throw Boom() }
        let viewModel = NotificationSettingsViewModel(client: client)
        await viewModel.load()

        await viewModel.set([.translation], enabled: false)

        #expect(viewModel.settings?.enabled == [.translation])
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.saving == false)
    }

    @Test func silencingAllAsksOnlyForWhatChanges() async {
        let calls = Calls()
        var client = SettingsClient.preview
        client.setAlert = { kind, enabled in
            calls.record("\(kind)-\(enabled)")
            return NotificationSettings(enabled: [], deviceCount: 1)
        }
        let viewModel = NotificationSettingsViewModel(client: client)
        await viewModel.load()

        await viewModel.set(AlertKind.allCases, enabled: false)

        #expect(calls.all == ["translation-false"])
        #expect(viewModel.settings?.enabled.isEmpty == true)
    }

    @Test func deniedPermissionBlocks() async {
        var client = SettingsClient.preview
        client.notificationAuthorization = { .denied }
        let viewModel = NotificationSettingsViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.blocked)
    }
}

@MainActor
struct ProfileSettingsViewModelTests {
    @Test func signOutForgetsTheDeviceFirst() async {
        let calls = Calls()
        var client = SettingsClient.preview
        client.forgetDevice = { calls.record("forget") }
        let viewModel = ProfileSettingsViewModel(client: client)

        await viewModel.signOut { calls.record("end") }

        #expect(calls.all == ["forget", "end"])
    }

    @Test func deletionEndsTheSession() async {
        let ended = Flag()
        let viewModel = ProfileSettingsViewModel(client: .preview)

        await viewModel.deleteAccount { ended.isOn = true }

        #expect(ended.isOn)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func lostAnswerOverAGoneAccountSaysNothing() async {
        var client = SettingsClient.preview
        client.deleteAccount = { throw Boom() }
        client.accountIsGone = { true }
        let viewModel = ProfileSettingsViewModel(client: client)

        await viewModel.deleteAccount {}

        #expect(viewModel.errorMessage == nil)
    }

    @Test func refusedDeletionSaysSoAndStops() async {
        let ended = Flag()
        var client = SettingsClient.preview
        client.deleteAccount = { throw Boom() }
        let viewModel = ProfileSettingsViewModel(client: client)

        await viewModel.deleteAccount { ended.isOn = true }

        #expect(ended.isOn == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isDeletingAccount == false)
    }
}

@MainActor
struct ChangelogViewModelTests {
    @Test func loadShowsTheEntries() async {
        let viewModel = ChangelogViewModel(client: .preview)

        await viewModel.load()

        #expect(viewModel.entries.map(\.version) == ["1.4", "1.3"])
        #expect(viewModel.isLoading == false)
    }

    @Test func failureIsSaid() async {
        var client = SettingsClient.preview
        client.changelog = { throw Boom() }
        let viewModel = ChangelogViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.entries.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }
}
