import UIKit

/// Where one ticked book of a shelf photo stands in the run that adds it.
enum ShelfAddProgress: Equatable, Sendable {
    case waiting
    case adding
    case added
    case failed(String)
}

#if DEBUG
/// A checklist as a shelf photo leaves it, for the previews and the tests: a
/// book to add, one already owned, and a spine the model could not read.
enum ShelfImportFixtures {
    static let photo: UIImage = {
        let size = CGSize(width: 600, height: 400)
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple]
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(x: 60 + index * 100, y: 40, width: 70, height: 320))
            }
        }
    }()

    static let books: [DetectedBook] = {
        let box = { (index: Int) in CGRect(x: (60 + Double(index) * 100) / 600, y: 0.1, width: 70.0 / 600, height: 0.8) }
        return [
            DetectedBook(id: 0, title: "Dune", authors: ["Frank Herbert"], publisher: nil, language: nil, format: nil, seriesName: "Dune", volume: 1, box: box(0), owned: false),
            DetectedBook(id: 1, title: "Le Messie de Dune", authors: ["Frank Herbert"], publisher: nil, language: nil, format: nil, seriesName: "Dune", volume: 2, box: box(1), owned: false),
            DetectedBook(id: 2, title: "Fondation", authors: ["Isaac Asimov"], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(2), owned: true),
            DetectedBook(id: 3, title: nil, authors: [], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(3), owned: false),
            DetectedBook(id: 4, title: "L'Étranger", authors: ["Albert Camus"], publisher: nil, language: nil, format: nil, seriesName: nil, volume: nil, box: box(4), owned: false),
        ]
    }()

    static let ticked: Set<Int> = [0, 1, 4]
    static let progress: [Int: ShelfAddProgress] = [0: .added, 1: .adding, 4: .failed("Le scan a échoué")]
}
#endif
