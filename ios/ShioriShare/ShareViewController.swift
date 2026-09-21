import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// What the share sheet hands over, dropped in the shared container for the app
/// to pick up.
///
/// The extension does not catalogue anything itself. It has no session — signing
/// in happens in the app, and an extension that carried its own credentials
/// would be a second place for them to leak from — so its whole job is to take
/// what was shared, put it where the app can reach it, and say so.
///
/// This shape is written here and read in the app. It is small on purpose: a
/// title, a link, or the name of an image file sitting beside it.
private struct SharedIntake: Codable {
    var text: String?
    var url: String?
    /// The file name of the image dropped beside this record in the same folder.
    var imageFile: String?
    var receivedAt: Date
}

/// The app group both halves see. Declared in each target's entitlements, and
/// spelled out here rather than shared in code: the extension is its own target
/// and cannot see the app's sources.
private let appGroup = "group.com.polyforms.shiori.app"

/// Where the handover lands. One folder, cleared by the app once it has read it.
private let intakeFolder = "shared-intake"

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: SharePrompt { [weak self] in self?.finish() })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await collect() }
    }

    /// Takes the first thing it recognizes out of what was shared. A page in
    /// Safari arrives as a URL and a title; a selection as text; a screenshot as
    /// an image. Any one of them is enough for the app to work from.
    private func collect() async {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        var intake = SharedIntake(receivedAt: .now)
        var imageData: Data?

        for provider in attachments {
            if imageData == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            {
                imageData = await load(provider, dataOf: .image)
            }
            if intake.url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                intake.url = (await loadURL(provider))?.absoluteString
            }
            if intake.text == nil,
                provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            {
                intake.text = await loadText(provider)
            }
        }

        write(intake, image: imageData)
    }

    /// The bytes behind an attachment. Asked for as data rather than as an
    /// object: Photos hands a screenshot over as a file, a web page as a
    /// `UIImage`, and neither of those crosses an actor boundary — `Data` does.
    private func load(_ provider: NSItemProvider, dataOf type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: data)
            }
        }
    }

    /// The page that was shared. Spelled out rather than made generic: the
    /// constraint `loadObject(ofClass:)` carries is an underscored bridging
    /// protocol, and restating it buys nothing for two call sites.
    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            _ = provider.loadObject(ofClass: URL.self) { value, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: value)
            }
        }
    }

    /// The text that was shared: a selection, or the title the page sends
    /// alongside its address.
    private func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            _ = provider.loadObject(ofClass: String.self) { value, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: value)
            }
        }
    }

    /// A failure here is swallowed: the sheet has already told the reader it
    /// worked, and the worst case is that Shiori opens on nothing new. There is
    /// nothing useful to say about a container that would not take a file.
    private func write(_ intake: SharedIntake, image: Data?) {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroup
            )
        else { return }
        let folder = container.appending(path: intakeFolder, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var record = intake
        if let image {
            let name = "\(UUID().uuidString).jpg"
            try? image.write(to: folder.appending(path: name), options: .atomic)
            record.imageFile = name
        }
        guard let data = try? JSONEncoder().encode(record) else { return }
        // The moment it was shared leads the name, so the app reads a pile of
        // them in the order they arrived rather than the order the file system
        // happens to list.
        let stamp = String(format: "%015.3f", record.receivedAt.timeIntervalSince1970)
        try? data.write(
            to: folder.appending(path: "\(stamp)-\(UUID().uuidString).json"),
            options: .atomic
        )
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// What the reader sees. It says where the book went and what to do next,
/// because nothing else will: the extension cannot catalogue on its own, so a
/// sheet that just closed would leave them wondering whether anything happened.
private struct SharePrompt: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Gardé pour Shiori")
                .font(.title3.weight(.semibold))
            Text("Ouvrez Shiori : le livre vous sera proposé, à vérifier avant d'être ajouté.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Terminé", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// One-shot flag guarding a continuation resumed from a callback the item
/// provider may call more than once, from any thread.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
