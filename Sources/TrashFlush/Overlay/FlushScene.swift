import AppKit

/// Where everything goes in the overlay window, in the window's own SwiftUI
/// coordinates (origin top left, y pointing down).
struct FlushScene {
    var size: CGSize
    /// Center of the Dock's Trash icon, where files fly out from.
    var trash: CGPoint
    /// Bottom center of the toilet.
    var toiletBase: CGPoint
    var captionCenter: CGPoint

    /// Size of the toilet drawing at scale 1, in points.
    static let toiletSize = CGSize(width: 110, height: 150)
    /// Center of the water, measured up from the toilet's base.
    static let bowlHeight: CGFloat = 84

    var bowlCenter: CGPoint { CGPoint(x: toiletBase.x, y: toiletBase.y - Self.bowlHeight) }

    /// The top of the arc: above both ends, higher for longer throws.
    var flightControl: CGPoint {
        let distance = hypot(bowlCenter.x - trash.x, bowlCenter.y - trash.y)
        return CGPoint(x: (trash.x + bowlCenter.x) / 2,
                       y: min(trash.y, bowlCenter.y) - 70 - distance * 0.35)
    }
}

extension FlushScene {
    /// Places the toilet just beside the Dock's Trash, on the side facing the
    /// middle of the screen, and returns the window frame that holds it all.
    static func layout(around trash: DockTrash) -> (frame: NSRect, scene: FlushScene) {
        let icon = trash.frame
        let bounds = trash.screen.frame.insetBy(dx: 8, dy: 8)
        let toilet = toiletSize

        var base: CGPoint
        switch trash.edge {
        case .bottom:
            let inward: CGFloat = icon.midX > bounds.midX ? -1 : 1
            base = CGPoint(x: icon.midX + inward * (icon.width / 2 + 100), y: icon.maxY + 10)
        case .left:
            base = CGPoint(x: icon.maxX + 110, y: icon.minY)
        case .right:
            base = CGPoint(x: icon.minX - 110, y: icon.minY)
        }
        base.x = min(max(base.x, bounds.minX + toilet.width / 2), bounds.maxX - toilet.width / 2)
        base.y = min(max(base.y, bounds.minY), bounds.maxY - toilet.height - 70)

        let toiletRect = CGRect(x: base.x - toilet.width / 2, y: base.y, width: toilet.width, height: toilet.height)
        let captionRect = CGRect(x: base.x - 130, y: toiletRect.maxY + 10, width: 260, height: 64)
        let arcTop = max(icon.midY, base.y + bowlHeight) + 40 + hypot(icon.midX - base.x, icon.midY - base.y) * 0.2

        let frame = icon.union(toiletRect).union(captionRect)
            .union(CGRect(x: icon.midX, y: arcTop, width: 1, height: 1))
            .insetBy(dx: -40, dy: -30)
            .intersection(trash.screen.frame)
            .integral

        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }
        let scene = FlushScene(size: frame.size,
                               trash: local(CGPoint(x: icon.midX, y: icon.midY)),
                               toiletBase: local(base),
                               captionCenter: local(CGPoint(x: captionRect.midX, y: captionRect.midY)))
        return (frame, scene)
    }
}
