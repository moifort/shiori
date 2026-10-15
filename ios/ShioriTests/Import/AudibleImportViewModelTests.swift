import Foundation
import Testing
@testable import Shiori

private let account = AudibleAccount(
    marketplace: .fr, connectedAt: .now, lastImportedAt: nil, autoSync: true
)

private func book(_ asin: String, held: Bool = false) -> ImportableBook {
    ImportableBook(
        asin: asin, title: "Livre \(asin)", authors: ["Auteur"], narrators: [], durationMinutes: 600,
        coverURL: nil, seriesName: nil, volume: nil, status: .toRead, finishedAt: nil, alreadyInLibrary: held
    )
}

/// Connected, with one title held and two to import; every write accepted.
private func connected(asked: Calls? = nil) -> AudibleClient {
    AudibleClient(
        connection: { (account, [book("A"), book("B", held: true), book("C")]) },
        startSignIn: { _ in throw Boom() },
        completeSignIn: { _ in account },
        importBooks: { asins in
            asked?.record(asins.sorted().joined(separator: ","))
            return asins.map { Book(id: $0, title: $0, authors: [], status: .toRead) }
        },
        setAutoSync: { _ in throw Boom() },
        syncNow: { (SyncOutcome(imported: 1, updated: 0), account, []) },
        disconnect: {}
    )
}

@MainActor
struct AudibleImportViewModelTests {
    @Test func everythingNotHeldStartsTicked() async {
        let viewModel = AudibleImportViewModel(client: connected())

        await viewModel.load()

        #expect(viewModel.isSelected(book("A")))
        #expect(!viewModel.isSelected(book("B", held: true)))
        #expect(viewModel.isSelected(book("C")))
    }

    @Test func importSendsWhatIsTicked() async {
        let asked = Calls()
        let viewModel = AudibleImportViewModel(client: connected(asked: asked))
        await viewModel.load()

        let imported = await viewModel.importSelected()

        #expect(asked.all == ["A,C"])
        #expect(imported.count == 2)
    }

    @Test func refusedAutoSyncLeavesTheSwitch() async {
        let viewModel = AudibleImportViewModel(client: connected())
        await viewModel.load()

        await viewModel.setAutoSync(false)

        #expect(viewModel.isAutoSyncOn)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func disconnectForgetsTheLibrary() async {
        let viewModel = AudibleImportViewModel(client: connected())
        await viewModel.load()

        await viewModel.disconnect()

        #expect(viewModel.account == nil)
        #expect(viewModel.books.isEmpty)
    }
}
