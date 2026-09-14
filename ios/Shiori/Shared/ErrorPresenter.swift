import SwiftUI

/// Captures errors from async API mutations so they can be surfaced in an alert
/// instead of being silently discarded with `try?`.
///
/// Usage:
/// ```swift
/// @State private var errorPresenter = ErrorPresenter()
///
/// // In an action closure:
/// await errorPresenter.run {
///     try await BookAPI.rate(...)
/// } onSuccess: {
///     showFavorite = false
/// }
///
/// // On the view (inside the sheet content if the action runs in a sheet,
/// // so the sheet stays open on failure):
/// .errorAlert(errorPresenter)
/// ```
@MainActor
@Observable
final class ErrorPresenter {
    var message: String?
    /// True while `run` is awaiting the network call — bind a button's spinner /
    /// disabled state to this so every mutation shows a loader.
    private(set) var isRunning = false

    /// Runs `operation`. On success, calls `onSuccess` (dismiss the sheet, refresh, ...).
    /// On failure, reports the error and stores its message so `.errorAlert` presents it;
    /// `onSuccess` is NOT called, so the sheet stays open and the user can retry or cancel.
    func run(
        _ operation: @MainActor () async throws -> Void,
        onSuccess: @MainActor () -> Void = {}
    ) async {
        isRunning = true
        defer { isRunning = false }
        do {
            try await operation()
            onSuccess()
        } catch {
            message = reportError(error)
        }
    }
}

extension View {
    /// Presents an alert whenever the given presenter holds an error message.
    func errorAlert(_ presenter: ErrorPresenter) -> some View {
        alert(
            "Une erreur est survenue",
            isPresented: Binding(
                get: { presenter.message != nil },
                set: { if !$0 { presenter.message = nil } }
            )
        ) {
            Button("OK") { presenter.message = nil }
        } message: {
            Text(presenter.message ?? "")
        }
    }
}
