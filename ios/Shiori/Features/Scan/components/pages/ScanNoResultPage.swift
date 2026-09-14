import SwiftUI

/// No book was recognized. An ordinary outcome, not a failure: a blurred shot or
/// a photo of something that is not a cover. It costs no scan, and saying so is
/// what keeps the reader trying again instead of assuming they were charged.
struct ScanNoResultPage: View {
    let onRetake: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Aucun livre reconnu", systemImage: "book.closed")
        } description: {
            Text("Cadrez la couverture entière, bien éclairée et sans reflet. Ce scan n'a pas été décompté.")
        } actions: {
            Button("Reprendre une photo", action: onRetake)
                .buttonStyle(.borderedProminent)
            Button("Ajouter à la main", action: onDismiss)
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ScanNoResultPage(onRetake: {}, onDismiss: {})
}
