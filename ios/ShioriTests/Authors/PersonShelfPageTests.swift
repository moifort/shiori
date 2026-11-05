import Foundation
import Testing
@testable import Shiori

@MainActor
struct PersonShelfPageTests {
    private func narrator(_ name: String, _ letter: String, surname: String? = nil) -> FollowedNarrator {
        FollowedNarrator(
            key: name.lowercased(),
            name: name,
            indexLetter: letter,
            shelvedAt: nil,
            books: [],
            surname: surname
        )
    }

    @Test func eachLetterIsOneSectionInAlphabeticalOrder() {
        let people = [
            narrator("Gary Fossier-Renna", "F"),
            narrator("Cédric Dumond", "D"),
            narrator("Julien Chatelet", "C"),
            narrator("Matthieu Dahan", "D"),
            narrator("村上春樹", "#"),
            narrator("Paul Bertin-Hugault", "B"),
        ]

        let sections = PersonShelfPage<FollowedNarrator>.letterSections(of: people)

        #expect(sections.map(\.letter) == ["B", "C", "D", "F", "#"])
        #expect(sections[2].people.map(\.name) == ["Cédric Dumond", "Matthieu Dahan"])
    }

    @Test func theSurnameIsTheBoldEndOfTheName() {
        let bolded = narrator("Arnauld Le Ridant", "L", surname: "Le Ridant")
        let plain = narrator("Arnauld Le Ridant", "L")

        #expect(PersonShelfPage<FollowedNarrator>.name(of: bolded) == boldEnd("Arnauld ", "Le Ridant"))
        #expect(PersonShelfPage<FollowedNarrator>.name(of: plain) == AttributedString("Arnauld Le Ridant"))
    }

    private func boldEnd(_ first: String, _ last: String) -> AttributedString {
        var bold = AttributedString(last)
        bold.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(first) + bold
    }
}
