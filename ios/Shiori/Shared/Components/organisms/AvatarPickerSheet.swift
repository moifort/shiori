import PhotosUI
import SwiftUI

/// Who the reader wants to be beside their name, chosen as Netflix has its
/// profiles chosen: a row of their own — a photo, or their initials — then a
/// row of heroes per shelf. Picking closes the sheet.
///
/// The photo comes through the system picker, which runs outside the app and
/// asks for no access to the library. The photo iCloud shows is out of reach:
/// iOS hands it to no app.
struct AvatarPickerSheet: View {
    let current: AccountAvatar
    let firstName: String?
    let onPick: (AccountAvatar) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var choosingPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    shelf("Vous") {
                        Button { choosingPhoto = true } label: {
                            choice(label: "Photo", isSelected: isPhoto) {
                                if isPhoto {
                                    AccountAvatarView(avatar: current, firstName: firstName, size: 72)
                                } else {
                                    Image(systemName: isLoadingPhoto ? "hourglass" : "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 72, height: 72)
                                        .background(Color(.tertiarySystemFill), in: .circle)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("avatar-photo")
                        Button { pick(.initials) } label: {
                            choice(label: "Initiales", isSelected: current == .initials) {
                                AccountAvatarView(avatar: .initials, firstName: firstName, size: 72)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("avatar-initials")
                    }
                    ForEach(AvatarHero.Shelf.allCases) { row in
                        shelf(row.title) {
                            ForEach(row.heroes) { hero in
                                Button { pick(.hero(hero)) } label: {
                                    choice(label: hero.name, isSelected: current == .hero(hero)) {
                                        AccountAvatarView(avatar: .hero(hero), firstName: nil, size: 72)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("avatar-\(hero.rawValue)")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
    }

    private var isPhoto: Bool {
        switch current {
        case .photo, .pickedPhoto: true
        case .initials, .hero: false
        }
    }

    private func shelf(_ title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) { content() }
        }
    }

    private func choice(
        label: LocalizedStringResource,
        isSelected: Bool,
        @ViewBuilder face: () -> some View
    ) -> some View {
        VStack(spacing: 6) {
            face()
                .padding(3)
                .overlay { Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2.5) }
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func pick(_ avatar: AccountAvatar) {
        onPick(avatar)
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let square = AccountAvatar.squarePhoto(from: data)
        else { return }
        pick(.pickedPhoto(square))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AvatarPickerSheet(current: .hero(.holmes), firstName: "Thibaut") { _ in }
    }
}
