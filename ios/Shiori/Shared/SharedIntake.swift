import Foundation

/// What the share extension left for the app to pick up.
///
/// The extension has no session of its own — signing in happens here, and an
/// extension carrying credentials would be a second place for them to leak
/// from — so it drops what was shared into the container both halves can see,
/// and the app catalogues it the next time it comes to the front.
///
/// This shape is written by `ShioriShare/ShareViewController.swift` and read
/// here. The two are separate targets and cannot share code, so the field names
/// and the group identifier are spelled out on both sides: change one and the
/// other stops seeing anything.
struct SharedIntake: Codable, Sendable {
    /// The page title, or the text the reader had selected.
    var text: String?
    /// The page that was shared.
    var url: String?
    /// A shared image, already written beside the record.
    var imageFile: String?
    var receivedAt: Date

    /// The app group both halves see, declared in each target's entitlements.
    static let appGroup = "group.com.polyforms.shiori.app"
    private static let folderName = "shared-intake"

    private static var folder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    /// What the extension left, oldest first, taken off the pile as it is read.
    ///
    /// Taken rather than peeked: a record that has been handed to the flow must
    /// not come back on the next foreground, and a reader who shares three
    /// pages gets three books rather than the last one three times.
    static func take() -> (intake: SharedIntake, image: Data?)? {
        guard let folder,
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
        else { return nil }

        let records = entries
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for record in records {
            defer { try? FileManager.default.removeItem(at: record) }
            guard let data = try? Data(contentsOf: record),
                let intake = try? JSONDecoder().decode(SharedIntake.self, from: data)
            else { continue }

            var image: Data?
            if let name = intake.imageFile {
                let file = folder.appending(path: name)
                image = try? Data(contentsOf: file)
                try? FileManager.default.removeItem(at: file)
            }
            return (intake, image)
        }
        return nil
    }

    /// Everything the extension left, dropped. Called when the session ends:
    /// whoever signs in next must not be handed the last reader's page.
    static func clear() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
