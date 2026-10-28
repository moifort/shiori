import SwiftUI
import UIKit

/// A hero of a novel a reader may wear as an avatar: classics of the public
/// domain beside characters of recent books, each drawn from its book's own
/// description rather than from any adaptation. The portraits are bundled in
/// the app; the server keeps only the name.
enum AvatarHero: String, CaseIterable, Identifiable, Sendable {
    case alice, dorothy, merlin, dracula
    case nemo, creature, timeTraveller, invisibleMan
    case holmes, lupin, dupin, rouletabille
    case carl, donut, daneel, seldon, yeWenjie, luoJi, shrike, paulAtreides, murderbot, rocky
    case gandalf, kvothe, vin, lockeLamora, violet, geralt
    case lisbeth, poirot, maigret, reacher

    var id: String { rawValue }

    /// The portrait in the asset catalogue.
    var imageName: String { "avatar-\(rawValue)" }

    /// The server's enum case: `timeTraveller` is `TIME_TRAVELLER`.
    var graphQLName: String {
        rawValue.replacing(/([A-Z])/) { "_\($0.output.1)" }.uppercased()
    }

    init?(graphQLName: String) {
        guard let hero = Self.allCases.first(where: { $0.graphQLName == graphQLName }) else { return nil }
        self = hero
    }

    var name: LocalizedStringResource {
        switch self {
        case .alice: "Alice"
        case .dorothy: "Dorothy"
        case .merlin: "Merlin"
        case .dracula: "Dracula"
        case .nemo: "Nemo"
        case .creature: "La Créature"
        case .timeTraveller: "Le Voyageur"
        case .invisibleMan: "L'Homme invisible"
        case .holmes: "Sherlock Holmes"
        case .lupin: "Arsène Lupin"
        case .dupin: "Dupin"
        case .rouletabille: "Rouletabille"
        case .carl: "Carl"
        case .donut: "Donut"
        case .daneel: "Daneel Olivaw"
        case .seldon: "Hari Seldon"
        case .yeWenjie: "Ye Wenjie"
        case .luoJi: "Luo Ji"
        case .shrike: "Le Gritche"
        case .paulAtreides: "Paul Atréides"
        case .murderbot: "AssaSynth"
        case .rocky: "Rocky"
        case .gandalf: "Gandalf"
        case .kvothe: "Kvothe"
        case .vin: "Vin"
        case .lockeLamora: "Locke Lamora"
        case .violet: "Violet"
        case .geralt: "Geralt"
        case .lisbeth: "Lisbeth Salander"
        case .poirot: "Hercule Poirot"
        case .maigret: "Maigret"
        case .reacher: "Jack Reacher"
        }
    }

    /// The first twelve, from books in the public domain.
    var isClassic: Bool {
        switch self {
        case .alice, .dorothy, .merlin, .dracula, .nemo, .creature, .timeTraveller, .invisibleMan,
             .holmes, .lupin, .dupin, .rouletabille: true
        default: false
        }
    }

    var shelf: Shelf {
        switch self {
        case .alice, .dorothy, .merlin, .dracula,
             .gandalf, .kvothe, .vin, .lockeLamora, .violet, .geralt, .carl, .donut: .fantasy
        case .nemo, .creature, .timeTraveller, .invisibleMan,
             .daneel, .seldon, .yeWenjie, .luoJi, .shrike, .paulAtreides, .murderbot, .rocky: .scienceFiction
        case .holmes, .lupin, .dupin, .rouletabille, .lisbeth, .poirot, .maigret, .reacher: .crime
        }
    }

    /// The rows of the picker, as Netflix groups its profiles by show.
    enum Shelf: CaseIterable, Identifiable {
        case fantasy, scienceFiction, crime

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .fantasy: "Fantasy"
            case .scienceFiction: "Science-fiction"
            case .crime: "Polar"
            }
        }

        /// The heroes of recent books first, the ones a reader knows best; the
        /// classics after.
        var heroes: [AvatarHero] {
            let shelved = AvatarHero.allCases.filter { $0.shelf == self }
            return shelved.filter { !$0.isClassic } + shelved.filter(\.isClassic)
        }
    }
}

/// What stands for the reader beside their name: their initials, a hero, or a
/// photo of their own — kept on the server, or just picked and not sent yet.
enum AccountAvatar: Equatable, Sendable {
    case initials
    case hero(AvatarHero)
    case photo(URL)
    /// A 512-pixel square JPEG, chosen in the onboarding before the account
    /// exists to keep it.
    case pickedPhoto(Data)

    /// The 512-pixel square JPEG the server keeps, cropped to the middle of
    /// whatever the reader picked: a face is rarely at the edge of a photo.
    static func squarePhoto(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let scale = target.width / side
            let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (target.width - drawn.width) / 2,
                y: (target.height - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            ))
        }
        return square.jpegData(compressionQuality: 0.85)
    }
}

/// The initials of a first name, or of two names: "Thibaut" is "T",
/// "Jean-Marc" is "JM".
func initials(of name: String?) -> String {
    let words = (name ?? "")
        .split(whereSeparator: { $0 == " " || $0 == "-" })
        .prefix(2)
    return words.compactMap(\.first).map { String($0).uppercased() }.joined()
}
