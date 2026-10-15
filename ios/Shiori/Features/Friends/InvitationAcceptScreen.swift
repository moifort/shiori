import SwiftUI

/// An invitation the reader arrived on by tapping a link, waiting to be taken up.
struct InvitationRequest: Identifiable, Equatable {
    let code: String
    var id: String { code }
}

/// Takes up an invitation opened from a link: what accepting shares, then
/// the friend it joined.
@MainActor
@Observable
final class InvitationAcceptViewModel {
    /// The reader's shelf as the sender will see it: what accepting shares.
    private(set) var myShelf: FriendProfile?
    private(set) var accepted: Friend?
    /// A refusal, said in an alert.
    var errorMessage: String?

    private let client: FriendsClient

    init(client: FriendsClient) {
        self.client = client
    }

    /// The summary is a nicety: the invitation can be accepted without it.
    func loadShelf() async {
        myShelf = try? await client.myShelf()
    }

    func accept(code: String) async {
        do {
            accepted = try await client.accept(code)
            // Accepting does not post the change notice (it changes no
            // library): the Partagé tab is told here, so the new friend is
            // already in the list when the reader gets there.
            NotificationCenter.default.post(name: .shioriDataDidChange, object: nil)
        } catch {
            errorMessage = reportError(error)
        }
    }
}

/// What a tapped invitation link opens on, connected.
///
/// It asks before it accepts. The link came from somewhere the reader does not
/// control — a message, a forwarded mail, a page — and accepting opens their
/// library to whoever sent it. One tap to arrive here is right; one tap to share
/// a library is not.
struct InvitationAcceptScreen: View {
    let request: InvitationRequest
    let onAccepted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InvitationAcceptViewModel

    init(request: InvitationRequest, onAccepted: @escaping () -> Void, client: FriendsClient = .live) {
        self.request = request
        self.onAccepted = onAccepted
        _viewModel = State(initialValue: InvitationAcceptViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            InvitationAcceptPage(myShelf: viewModel.myShelf, accepted: viewModel.accepted) { action in
                switch action {
                case .accept:
                    await viewModel.accept(code: request.code)
                    if viewModel.accepted != nil { onAccepted() }
                case .close: dismiss()
                }
            }
            .alert(
                "Invitation refusée",
                isPresented: .init(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
        .task { await viewModel.loadShelf() }
    }
}
