import SwiftUI

/// The three reading statuses as a segmented control, each with the symbol the
/// cover badge and the library filter draw, so the same state looks the same
/// wherever the reader meets it.
///
/// Drawn by hand rather than with a segmented `Picker`: a native segment shows a
/// title or an image, never both, and the symbol is the point of this control.
struct ReadingStatusPicker: View {
    @Binding var status: ReadingStatus
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReadingStatus.allCases) { option in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { status = option }
                } label: {
                    // An HStack, not a Label: inside a List a Label reserves the
                    // row's icon column, which pushes the title a thumb away.
                    HStack(spacing: 5) {
                        Image(systemName: option.symbol).imageScale(.small)
                        Text(option.label)
                    }
                        .font(.subheadline.weight(status == option ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if status == option {
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "selection", in: selection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(status == option ? .isSelected : [])
                .accessibilityIdentifier("status-\(option.rawValue)")
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .sensoryFeedback(.selection, trigger: status)
    }
}

#Preview {
    @Previewable @State var status = ReadingStatus.reading
    List {
        ReadingStatusPicker(status: $status)
    }
}
