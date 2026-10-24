import SwiftUI

/// How an iPhone Duo's inner screen is held across a view, as far as laying
/// out two pages goes. Read from the fold's `division` region, in the view's
/// own coordinates: a view the fold does not cross is `single`, whatever the
/// device does.
///
/// Apple names the poses after what the reader holds: laid flat, the screen is
/// one wide desk; partly folded on its side, it reads like a book, a page each
/// side of the crease; partly folded upright, it stands like a laptop, a screen
/// above the crease and a keyboard below.
enum FoldPosture: Equatable {
    /// A phone, the Duo's outer screen, or a view the fold does not cross.
    case single
    /// Laid flat: no crease to keep clear of, the pages part on its line.
    case flat(line: CGFloat)
    /// Partly folded, held like a book: one page left of the crease, one right.
    /// The span is the crease and the margins the system asks around it.
    case book(crease: ClosedRange<CGFloat>)
    /// Partly folded, standing like a laptop: one page above the crease, one
    /// below.
    case laptop(crease: ClosedRange<CGFloat>)

    /// Partly folded, either way: the posture where the crease is in the way.
    var isFolded: Bool {
        switch self {
        case .book, .laptop: true
        case .single, .flat: false
        }
    }
}

extension GeometryProxy {
    /// The posture of the Duo across this view. `isRegular` is the view's
    /// horizontal size class: where no fold is reported — before iOS 27.1, in
    /// a preview — a regular width at least two phones wide still lays out as
    /// a desk, so the two pages can be seen without the device.
    func foldPosture(isRegular: Bool) -> FoldPosture {
        #if DEBUG
        if let forced = FoldPosture.forced(in: size) { return forced }
        #endif
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            if let fold = reservedRegions(kind: .division, options: .includeInactive).first {
                return FoldPosture(fold: fold.frame, margins: fold.margins, isActive: fold.isActive, in: size)
            }
        }
        #endif
        return isRegular && size.width >= FoldPosture.minimumSpread ? .flat(line: size.width / 2) : .single
    }
}

extension FoldPosture {
    /// Below this width two pages would each be narrower than a phone.
    static let minimumSpread: CGFloat = 700
    /// A page narrower or shorter than this is not worth laying out apart.
    static let minimumPage: CGFloat = 280

    /// The posture a fold reported as `fold` gives a view of `size`. A crease
    /// running down the view parts it left and right, one running across parts
    /// it top and bottom; laid flat, only a crease down the view counts, as a
    /// tall flat screen reads best as one.
    init(fold: CGRect, margins: EdgeInsets, isActive: Bool, in size: CGSize) {
        let runsDown = fold.height >= fold.width
        if !isActive {
            let line = fold.midX
            self = runsDown && line >= Self.minimumPage && size.width - line >= Self.minimumPage
                ? .flat(line: line) : .single
            return
        }
        if runsDown {
            let crease = (fold.minX - margins.leading)...(fold.maxX + margins.trailing)
            self = crease.lowerBound >= Self.minimumPage && size.width - crease.upperBound >= Self.minimumPage
                ? .book(crease: crease) : .single
        } else {
            let crease = (fold.minY - margins.top)...(fold.maxY + margins.bottom)
            self = crease.lowerBound >= Self.minimumPage && size.height - crease.upperBound >= Self.minimumPage
                ? .laptop(crease: crease) : .single
        }
    }

    /// Where the two pages sit in a view of `size`, or nil when it is one page.
    func pages(in size: CGSize) -> (first: CGRect, second: CGRect)? {
        switch self {
        case .single:
            return nil
        case let .flat(line):
            return (
                CGRect(x: 0, y: 0, width: line, height: size.height),
                CGRect(x: line, y: 0, width: size.width - line, height: size.height)
            )
        case let .book(crease):
            return (
                CGRect(x: 0, y: 0, width: crease.lowerBound, height: size.height),
                CGRect(x: crease.upperBound, y: 0, width: size.width - crease.upperBound, height: size.height)
            )
        case let .laptop(crease):
            return (
                CGRect(x: 0, y: 0, width: size.width, height: crease.lowerBound),
                CGRect(x: 0, y: crease.upperBound, width: size.width, height: size.height - crease.upperBound)
            )
        }
    }
}

#if DEBUG
extension FoldPosture {
    /// A posture forced by the `-posture flat|book|laptop` launch argument, on
    /// any view wide (or, for the laptop, tall) enough to be the whole inner
    /// screen: the simulator cannot be folded from the command line, so the
    /// captures of each posture are taken on a screen held flat — the laptop
    /// on its side, its crease across the middle.
    static func forced(in size: CGSize) -> FoldPosture? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-posture"),
              index + 1 < ProcessInfo.processInfo.arguments.count
        else { return nil }
        // A view smaller than the screen is a page of it, which the real fold
        // would not cross: it stays one page, as on the device.
        let crease: CGFloat = 28
        switch ProcessInfo.processInfo.arguments[index + 1] {
        case "flat":
            return size.width >= minimumSpread ? .flat(line: size.width / 2) : .single
        case "book":
            return size.width >= minimumSpread
                ? .book(crease: (size.width - crease) / 2...(size.width + crease) / 2) : .single
        case "laptop":
            return size.height >= 500
                ? .laptop(crease: (size.height - crease) / 2...(size.height + crease) / 2) : .single
        default:
            return nil
        }
    }
}
#endif
