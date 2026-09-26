import Foundation

public enum Target: String, CaseIterable, Codable {
    case screen, window, area, text
}

public enum Kind: String, Codable {
    case photo, video
}

/// What the bar offers and how ⌘← ⌘→ and ⌘⇧5 move through it. Seven buttons, like the
/// system's six: four stills, then three recordings.
public struct BarState: Equatable {
    public var target: Target
    public var kind: Kind

    public init(target: Target = .area, kind: Kind = .photo) {
        self.target = target
        self.kind = kind
    }

    /// Text recognition has no meaning for a movie.
    public static func targets(for kind: Kind) -> [Target] {
        kind == .video ? [.screen, .window, .area] : Target.allCases
    }

    /// Every button, left to right.
    public static let all: [BarState] =
        targets(for: .photo).map { BarState(target: $0, kind: .photo) }
        + targets(for: .video).map { BarState(target: $0, kind: .video) }

    public mutating func step(_ delta: Int) {
        let i = Self.all.firstIndex(of: self) ?? 0
        self = Self.all[(i + delta + Self.all.count) % Self.all.count]
    }

    public mutating func toggleKind() {
        kind = kind == .photo ? .video : .photo
        if !Self.targets(for: kind).contains(target) { target = .area }
    }

    /// Whether this target needs a rectangle before it can commit.
    public var needsSelection: Bool { target == .area || target == .text }
}
