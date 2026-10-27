import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UIActivityViewController`, presented as a sheet:
/// the system share sheet for a text only known once the reader asked, which
/// `ShareLink` cannot wait for.
struct ActivityView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
