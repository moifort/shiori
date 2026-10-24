import SwiftUI

/// The camera's controls as a page of their own, on an unfolded iPhone Duo:
/// what to photograph and the shutter, beside the viewfinder held flat or like
/// a book, under it held like a laptop, as the Camera app keeps the controls
/// where the hand rests. The viewfinder's page is left to the cover.
struct CameraControlsPage<Accessory: View>: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    let shutterLabel: LocalizedStringKey
    let shutterIdentifier: String
    let onShutter: () -> Void
    /// What sits left of the shutter: the photo picker, where the flow has one.
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            HStack(spacing: 44) {
                accessory()
                    .frame(width: 52, height: 52)
                Button(action: onShutter) {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 84, height: 84)
                        .overlay(Circle().fill(.white).padding(7))
                }
                .accessibilityLabel(Text(shutterLabel))
                .accessibilityIdentifier(shutterIdentifier)
                // Balances the accessory, so the shutter stays centred.
                Color.clear
                    .frame(width: 52, height: 52)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

extension CameraControlsPage where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        hint: LocalizedStringKey,
        shutterLabel: LocalizedStringKey,
        shutterIdentifier: String,
        onShutter: @escaping () -> Void
    ) {
        self.init(
            title: title,
            hint: hint,
            shutterLabel: shutterLabel,
            shutterIdentifier: shutterIdentifier,
            onShutter: onShutter,
            accessory: { EmptyView() }
        )
    }
}

#if DEBUG
#Preview("Beside the viewfinder", traits: .fixedLayout(width: 951, height: 669)) {
    TwoPages {
        Color.gray.overlay(ViewfinderOverlay(leavesRoomForShutter: false))
    } second: {
        CameraControlsPage(
            title: "Scanner une couverture",
            hint: "Cadrez la couverture dans le viseur, bien éclairée.",
            shutterLabel: "Scanner la couverture",
            shutterIdentifier: "scan-shutter",
            onShutter: {}
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}
#endif
