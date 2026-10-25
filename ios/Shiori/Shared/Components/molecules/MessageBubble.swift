import SwiftUI

/// One line of a conversation, as Messages draws it: the reader's own words
/// in a blue bubble on the trailing edge, someone else's in a grey one on
/// the leading edge under their name, their initial in a circle beside it as
/// a group's messages are signed. The bubble's tail points to whoever
/// speaks. A tap, where one is given, corrects the words.
struct MessageBubble: View {
    let text: String
    /// The reader's own words, drawn as Messages draws "me".
    var isMine = false
    /// Who else speaks, over their bubble. Ignored for the reader's own.
    var sender: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                avatar
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine, let sender {
                    Text(sender)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
                bubble
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder private var bubble: some View {
        let shape = BubbleShape(tailOnTrailingEdge: isMine)
        let content = Text(text)
            .font(.body)
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isMine ? Color(.systemBlue) : Color(.systemGray5), in: shape)
            .contentShape(shape)
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// The sender's initial on a grey disc, as Messages draws a contact
    /// without a photo.
    private var avatar: some View {
        Text(String(sender?.prefix(1) ?? "?").uppercased())
            .font(.subheadline.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color(.systemGray2), in: .circle)
            .accessibilityHidden(true)
    }
}

/// A Messages bubble: a rounded rectangle whose bottom corner, on the side
/// of whoever speaks, flares out into a short tail.
struct BubbleShape: Shape {
    var tailOnTrailingEdge: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = 6
        var p = Path()
        // Drawn with the tail on the right, then mirrored for the left.
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addCurve(
            to: CGPoint(x: rect.maxX + tail, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - r / 2),
            control2: CGPoint(x: rect.maxX + tail / 2, y: rect.maxY - 2)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX - r / 2, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY + 1),
            control2: CGPoint(x: rect.maxX - r / 4, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        if tailOnTrailingEdge { return p }
        return p.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -rect.width - 2 * rect.minX, y: 0))
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(text: "Si tu as aimé Hypérion, la suite est encore plus belle.", sender: "Camille", action: {})
        MessageBubble(text: "Le ton change complètement après les deux premiers tomes : moins de pèlerins, plus de fuite.", isMine: true, action: {})
        MessageBubble(text: "Oui.", isMine: true)
    }
    .padding(20)
    .background(Color(.systemGroupedBackground))
}
