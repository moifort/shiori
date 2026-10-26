import SwiftUI

/// A short white bar on a translucent track, as the TV app tells how far an
/// episode got: under a recording's "68%", on a series card.
struct ProgressBar: View {
    let fraction: Double
    var width: CGFloat = 40

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .frame(width: width, height: 4)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.white)
                    .frame(width: width * min(max(fraction, 0), 1), height: 4)
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        ProgressBar(fraction: 0.68)
        ProgressBar(fraction: 0.2, width: 24)
    }
    .padding()
    .background(.black)
}
