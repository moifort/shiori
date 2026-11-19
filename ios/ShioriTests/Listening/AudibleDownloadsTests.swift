import Foundation
import Testing
@testable import Shiori

@Suite("Where a downloaded Audible title is kept")
struct AudibleDownloadsTests {
    private let home = "/var/mobile/Containers/Data/Application/24BAD114-FDF2-4F44-B2E1-54066E22CD17"
    private let kept = "Library/com.apple.UserManagedAssets.BBr9iE/Interf%C3%A9rence_BE659D2132DC4290.movpkg"

    @Test("a location under the home folder is kept relative to it")
    func underHome() {
        #expect(AudibleDownloads.relativePath(of: "\(home)/\(kept)", home: home) == kept)
    }

    @Test("the location iOS hands back, under /.nofollow/private, is kept relative too")
    func underNoFollow() {
        let location = "/.nofollow/private\(home)/\(kept)"
        #expect(AudibleDownloads.relativePath(of: location, home: home) == kept)
    }

    @Test("a location recorded in whole under an earlier container is repaired")
    func earlierContainer() {
        let earlier = "/.nofollow/private/var/mobile/Containers/Data/Application/0B5C6E1A-0000-4000-8000-000000000000/\(kept)"
        #expect(AudibleDownloads.relativePath(of: earlier, home: home) == kept)
    }

    @Test("a relative path stays as it is")
    func alreadyRelative() {
        #expect(AudibleDownloads.relativePath(of: kept, home: home) == kept)
    }
}
