import SwiftUI

/// The sheet behind "Progression": the page the reader reached, typed on a
/// keypad of its own under a large figure, as a phone number is dialled, with
/// how far that is into the book and what is left. "Lu" and "Abandonné" end
/// the reading from here, the page typed kept on a book given up.
///
/// The figure opens on the page last recorded, and the first key replaces
/// it, as a field whose text is selected: the reader types where they are
/// now, not a correction of where they were. A digit that would run past the
/// last page is refused, so the figure never reads more than the book holds.
struct ReadingProgressSheet: View {
    let current: Int?
    let pageCount: Int?
    /// Saves the page typed, nil when untouched, then the status chosen, if
    /// any. Answers why it failed, or nil once saved.
    let onSave: (_ page: Int?, _ status: ReadingStatus?) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var digits: String
    /// No key pressed yet: the figure is the page recorded, the next digit
    /// replaces it.
    @State private var isPristine = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let maxDigits = 5

    init(
        current: Int?,
        pageCount: Int?,
        onSave: @escaping (_ page: Int?, _ status: ReadingStatus?) async -> String?
    ) {
        self.current = current
        self.pageCount = pageCount
        self.onSave = onSave
        _digits = State(initialValue: current.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                figure
                    .padding(.top, 8)
                progress
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                endings
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Spacer(minLength: 16)
                keypad
            }
            .navigationTitle("Où en êtes-vous ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmingAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {
                        await save(then: nil)
                    }
                    .disabled(edited == nil || isSaving)
                    .accessibilityIdentifier("progress-save")
                }
            }
            .disabled(isSaving)
            .alert(
                "Une erreur est survenue",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.height(542)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Figure

    private var figure: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(verbatim: digits.isEmpty ? "0" : digits)
                    .foregroundStyle(digits.isEmpty ? .tertiary : .primary)
                    .contentTransition(.numericText())
                Caret()
            }
            .font(.system(size: 76, weight: .heavy).monospacedDigit())
            .tracking(-2.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Page \(typed ?? 0)"))
            .accessibilityIdentifier("progress-page")
            if let pageCount {
                Text("sur **\(pageCount)** pages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The share read, the page recorded before under it in a paler band, and
    /// what that leaves.
    @ViewBuilder private var progress: some View {
        if let pageCount {
            let shown = min(typed ?? 0, pageCount)
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.quaternary)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .label))
                                .frame(width: proxy.size.width * CGFloat(shown) / CGFloat(pageCount))
                        }
                        .animation(.snappy, value: shown)
                }
                .frame(height: 6)
                HStack {
                    Text(verbatim: "\(shown * 100 / pageCount)%")
                    Spacer()
                    Text("\(pageCount - shown) restantes")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The reading ended from the sheet: read through, or given up where the
    /// figure says.
    private var endings: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await save(then: .read) }
                } label: {
                    Label("Lu", systemImage: ReadingStatus.read.symbol)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("progress-read")
                Button {
                    Task { await save(then: .dropped) }
                } label: {
                    Label("Abandonné", systemImage: ReadingStatus.dropped.symbol)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("progress-dropped")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    // MARK: - Keypad

    private var keypad: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)
        return LazyVGrid(columns: columns, spacing: 7) {
            ForEach(Key.all) { key in
                switch key {
                case .blank:
                    Color.clear.frame(height: 46)
                case let .digit(digit, letters):
                    Button { type(digit) } label: {
                        VStack(spacing: 1) {
                            Text(verbatim: String(digit))
                                .font(.system(size: 25))
                            if let letters {
                                Text(verbatim: letters)
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.fill.secondary, in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: String(digit)))
                case .delete:
                    Button(action: erase) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Effacer"))
                }
            }
        }
        .sensoryFeedback(.selection, trigger: digits)
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.fill.quinary)
    }

    private enum Key: Identifiable {
        case digit(Int, String?)
        case blank
        case delete

        var id: String {
            switch self {
            case let .digit(digit, _): "\(digit)"
            case .blank: "blank"
            case .delete: "delete"
            }
        }

        static let all: [Key] = [
            .digit(1, nil), .digit(2, "ABC"), .digit(3, "DEF"),
            .digit(4, "GHI"), .digit(5, "JKL"), .digit(6, "MNO"),
            .digit(7, "PQRS"), .digit(8, "TUV"), .digit(9, "WXYZ"),
            .blank, .digit(0, nil), .delete,
        ]
    }

    private func type(_ digit: Int) {
        let next = (isPristine ? "" : digits) + String(digit)
        let trimmed = String(Int(next) ?? 0)
        guard trimmed.count <= Self.maxDigits else { return }
        if let pageCount, let value = Int(trimmed), value > pageCount { return }
        isPristine = false
        withAnimation(.snappy) { digits = trimmed == "0" ? "" : trimmed }
    }

    private func erase() {
        isPristine = false
        withAnimation(.snappy) { digits = String(digits.dropLast()) }
    }

    // MARK: - Saving

    private var typed: Int? { Int(digits) }

    /// The page to send: one typed, past zero, that differs from the one
    /// recorded.
    private var edited: Int? {
        guard let typed, typed > 0, typed != current else { return nil }
        return typed
    }

    private func save(then status: ReadingStatus?) async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(edited, status) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

/// The text cursor after the figure, blinking as a field's does.
private struct Caret: View {
    @State private var isOn = true

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(uiColor: .label))
            .frame(width: 3, height: 62)
            .opacity(isOn ? 1 : 0)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(530))
                    isOn.toggle()
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ReadingProgressSheet(current: 214, pageCount: 662) { _, _ in nil }
    }
}
