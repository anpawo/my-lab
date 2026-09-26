import CoreGraphics
import Foundation

/// AppKit global rect (origin bottom-left of the main screen) → ScreenCaptureKit `sourceRect`:
/// local to the display, origin top-left, still in points.
public func displayLocal(_ r: CGRect, in screen: CGRect) -> CGRect {
    CGRect(x: r.minX - screen.minX, y: screen.maxY - r.maxY, width: r.width, height: r.height)
}

/// The pixel rect to crop out of a frozen image of `screen` taken at `scale`.
public func pixelCrop(_ r: CGRect, in screen: CGRect, scale: CGFloat) -> CGRect {
    let l = displayLocal(r, in: screen)
    return CGRect(x: (l.minX * scale).rounded(), y: (l.minY * scale).rounded(),
                  width: (l.width * scale).rounded(), height: (l.height * scale).rounded())
}

/// CoreGraphics global rect (origin top-left) → AppKit global rect.
public func appKit(_ r: CGRect, mainHeight: CGFloat) -> CGRect {
    CGRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
}

public func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
    CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
}

/// Arrow keys: move by (dx, dy), or grow by it when `resize`. Never leaves `bounds`.
public func nudge(_ r: CGRect, dx: CGFloat, dy: CGFloat, resize: Bool, bounds: CGRect) -> CGRect {
    var out = r
    if resize {
        out.size.width = max(1, r.width + dx)
        out.size.height = max(1, r.height + dy)
        out.size.width = min(out.width, bounds.maxX - out.minX)
        out.size.height = min(out.height, bounds.maxY - out.minY)
    } else {
        out.origin.x = min(max(r.minX + dx, bounds.minX), bounds.maxX - r.width)
        out.origin.y = min(max(r.minY + dy, bounds.minY), bounds.maxY - r.height)
    }
    return out
}

/// The eight handles as (fx, fy) fractions of the rect; index order is stable for hit-testing.
public let handles: [(CGFloat, CGFloat)] = [
    (0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5),
]

public func handlePoint(_ r: CGRect, _ i: Int) -> CGPoint {
    CGPoint(x: r.minX + r.width * handles[i].0, y: r.minY + r.height * handles[i].1)
}

/// Drags handle `i` of `r` to `p`; the opposite side stays put. Returns a normalised rect.
public func resized(_ r: CGRect, handle i: Int, to p: CGPoint) -> CGRect {
    let (fx, fy) = handles[i]
    var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
    if fx == 0 { minX = p.x } else if fx == 1 { maxX = p.x }
    if fy == 0 { minY = p.y } else if fy == 1 { maxY = p.y }
    return rect(from: CGPoint(x: minX, y: minY), to: CGPoint(x: maxX, y: maxY))
}

/// The same shape macOS uses, plus the app for a window shot: `Screenshot Safari 2026-…`.
public func fileName(kind: String, app: String? = nil, ext: String, at date: Date = Date()) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    let app = app.map { " " + $0.replacingOccurrences(of: "/", with: "-") } ?? ""
    return "\(kind)\(app) \(f.string(from: date)).\(ext)"
}

/// `r` minus `cut`: up to four non-overlapping rects.
public func subtract(_ r: CGRect, _ cut: CGRect) -> [CGRect] {
    let c = r.intersection(cut)
    guard !c.isNull, !c.isEmpty else { return [r] }
    var out: [CGRect] = []
    if c.minY > r.minY { out.append(CGRect(x: r.minX, y: r.minY, width: r.width, height: c.minY - r.minY)) }
    if c.maxY < r.maxY { out.append(CGRect(x: r.minX, y: c.maxY, width: r.width, height: r.maxY - c.maxY)) }
    if c.minX > r.minX { out.append(CGRect(x: r.minX, y: c.minY, width: c.minX - r.minX, height: c.height)) }
    if c.maxX < r.maxX { out.append(CGRect(x: c.maxX, y: c.minY, width: r.maxX - c.maxX, height: c.height)) }
    return out
}

/// What is left of `r` once the windows in front of it are taken away.
public func visible(_ r: CGRect, behind fronts: [CGRect]) -> [CGRect] {
    fronts.reduce([r]) { rects, f in rects.flatMap { subtract($0, f) } }
}
