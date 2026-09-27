import SwiftUI

/// Drives one shelf photo: capture, detection, the checklist, then adding the
/// ticked books three at a time.
///
/// Adding is owned here rather than by a view, so closing the sheet does not
/// cancel it: the books keep landing in the library while the app lives. A
/// book not yet saved when the app is killed is simply not there; importing
/// the photo again shows the saved ones as already owned.
@MainActor
@Observable
final class ShelfImportViewModel {
    enum Step: Equatable {
        case camera
        case detecting
        case checklist
        case noResult
        case failed
        case adding
    }

    enum Progress: Equatable {
        case waiting
        case adding
        case added
        case failed(String)
    }

    /// The photo is sent at this size: a spine's title is a few pixels tall,
    /// where a cover's reads fine at 1000.
    nonisolated static let photoDimension: CGFloat = 2000
    private static let parallelAdds = 3

    private(set) var step: Step = .camera
    /// The very image the server saw, so the boxes crop what it read.
    private(set) var photo: UIImage?
    private(set) var jpeg: Data?
    private(set) var books: [DetectedBook] = []
    private(set) var ticked: Set<Int> = []
    private(set) var progress: [Int: Progress] = [:]
    /// What is left of the allowance, month and granted scans together. Nil
    /// until read, or when it could not be.
    private(set) var remainingScans: Int?
    private(set) var failure: String?
    var paywallShown = false
    @ObservationIgnored private var crops: [Int: UIImage] = [:]

    var tickedCount: Int { ticked.count }

    /// Every chosen book is in the library.
    var isDone: Bool {
        !progress.isEmpty && progress.values.allSatisfy { $0 == .added }
    }

    /// More books ticked than scans left: the checklist says how many remain
    /// rather than starting a run that would stop halfway.
    var exceedsAllowance: Bool {
        remainingScans.map { tickedCount > $0 } ?? false
    }

    func detect(_ jpeg: Data) async {
        self.jpeg = jpeg
        photo = UIImage(data: jpeg)
        crops = [:]
        failure = nil
        step = .detecting
        do {
            async let found = ShelfAPI.detect(jpeg: jpeg)
            async let quota = try? SubscriptionAPI.quota()
            books = try await found
            remainingScans = await quota?.totalRemaining
            track(.shelfDetected(books: books.count))
            ticked = Set(books.filter { !$0.owned && $0.isNamed }.map(\.id))
            step = books.isEmpty ? .noResult : .checklist
        } catch let APIError.domain(code, _) where code == "PREMIUM_REQUIRED" || code == "QUOTA_EXHAUSTED" {
            step = .camera
            paywallShown = true
        } catch {
            failure = reportError(error)
            step = .failed
        }
    }

    /// Runs the detection again on the photo that failed. It spends nothing:
    /// detection is free, only the books kept are counted.
    func retry() async {
        guard let jpeg else { return retake() }
        await detect(jpeg)
    }

    func retake() {
        jpeg = nil
        photo = nil
        books = []
        ticked = []
        progress = [:]
        crops = [:]
        failure = nil
        step = .camera
    }

    /// An unreadable book cannot be ticked until the reader names it.
    func toggle(_ id: Int) {
        guard books.first(where: { $0.id == id })?.isNamed == true else { return }
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    /// The reader's reading of the spine replaces the model's, and ticks it.
    func correct(_ id: Int, title: String, authors: [String]) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        books[index].title = trimmed
        books[index].authors = authors
        ticked.insert(id)
    }

    /// The book cut out of the reader's photo, cut once and kept.
    func crop(of book: DetectedBook) -> UIImage? {
        if let cached = crops[book.id] { return cached }
        let cropped = photo?.crop(to: book.box)
        crops[book.id] = cropped
        return cropped
    }

    func addTicked() {
        let chosen = books.filter { ticked.contains($0.id) }
        progress = Dictionary(uniqueKeysWithValues: chosen.map { ($0.id, Progress.waiting) })
        step = .adding
        Task { await add(chosen) }
    }

    func retryAdding(_ id: Int) {
        guard let book = books.first(where: { $0.id == id }) else { return }
        progress[id] = .waiting
        Task { await add([book]) }
    }

    /// Three at a time: each book is a grounded model call of several seconds,
    /// and a shelf one after the other would take minutes.
    private func add(_ chosen: [DetectedBook]) async {
        await withTaskGroup(of: Void.self) { group in
            var pending = chosen[...]
            for _ in 0 ..< min(Self.parallelAdds, pending.count) {
                let book = pending.removeFirst()
                group.addTask { await self.addOne(book) }
            }
            while await group.next() != nil, let book = pending.popFirst() {
                group.addTask { await self.addOne(book) }
            }
        }
    }

    private func addOne(_ book: DetectedBook) async {
        progress[book.id] = .adding
        do {
            let scanned = try await ShelfAPI.describe(book)
            _ = try await BookAPI.add(scanned.asDraft)
            track(.bookAdded(source: .shelf))
            progress[book.id] = .added
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            progress[book.id] = .failed(String(localized: "Scans épuisés"))
        } catch {
            progress[book.id] = .failed(reportError(error))
        }
    }
}

#if DEBUG
extension ShelfImportViewModel {
    /// A checklist as a shelf photo leaves it, for the previews: a book to add,
    /// one already owned, and a spine the model could not read.
    static func preview(step: Step = .checklist) -> ShelfImportViewModel {
        let model = ShelfImportViewModel()
        let size = CGSize(width: 600, height: 400)
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple]
        model.photo = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(x: 60 + index * 100, y: 40, width: 70, height: 320))
            }
        }
        let box = { (index: Int) in CGRect(x: (60 + Double(index) * 100) / 600, y: 0.1, width: 70.0 / 600, height: 0.8) }
        model.books = [
            DetectedBook(id: 0, title: "Dune", authors: ["Frank Herbert"], publisher: nil, language: nil, format: nil, seriesName: "Dune", volume: 1, box: box(0), owned: false),
            DetectedBook(id: 1, title: "Le Messie de Dune", authors: ["Frank Herbert"], publisher: nil, language: nil, format: nil, seriesName: "Dune", volume: 2, box: box(1), owned: false),
            DetectedBook(id: 2, title: "Fondation", authors: ["Isaac Asimov"], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(2), owned: true),
            DetectedBook(id: 3, title: nil, authors: [], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(3), owned: false),
            DetectedBook(id: 4, title: "L'Étranger", authors: ["Albert Camus"], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(4), owned: false),
        ]
        model.ticked = [0, 1, 4]
        model.remainingScans = 94
        if step == .adding {
            model.progress = [0: .added, 1: .adding, 4: .failed("Le scan a échoué")]
        }
        model.step = step
        return model
    }
}
#endif
