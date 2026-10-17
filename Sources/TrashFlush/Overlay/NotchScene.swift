import AppKit
import TrashFlushCore

/// Where everything goes in the full-screen overlay, in the window's own
/// SwiftUI coordinates (origin top left, y pointing down).
struct NotchScene {
    var size: CGSize
    /// Center of the Dock's Trash icon while the Dock is showing.
    var trash: CGPoint
    var trashIconSize: CGFloat
    /// Unit vector from the Dock's edge into the screen.
    var away: CGVector
    /// The Dock is hidden, so a stand-in Trash peeks up to throw the files.
    /// Otherwise they climb out of the Dock's own Trash.
    var peeksTrash: Bool
    var style: NotchStyle
    /// Top of the black shape: 0 for a real notch, a little lower for the pill.
    var top: CGFloat
    var centerX: CGFloat
    /// Height of the camera housing. The island's text goes below it.
    var cameraHeight: CGFloat

    /// How far the stand-in Trash travels to get off the screen.
    static let peekDistance: CGFloat = 120
    static let fileSize: CGFloat = 48

    /// Where files disappear into, which follows the notch as it opens.
    func mouth(height: Double) -> CGPoint {
        CGPoint(x: centerX, y: top + height * 0.42)
    }

    /// The stand-in Trash's center, `offset` 0 when peeked up, 1 when off the screen.
    func standIn(offset: Double) -> CGPoint {
        CGPoint(x: trash.x - away.dx * Self.peekDistance * offset,
                y: trash.y - away.dy * Self.peekDistance * offset)
    }
}

extension NotchScene {
    static func layout(around trash: DockTrash) -> (frame: NSRect, scene: NotchScene) {
        let screen = trash.screen
        let frame = screen.frame
        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y) }

        let away: CGVector = switch trash.edge {
        case .bottom: CGVector(dx: 0, dy: -1)
        case .left: CGVector(dx: 1, dy: 0)
        case .right: CGVector(dx: -1, dy: 0)
        }

        let style: NotchStyle, top: CGFloat, camera: CGFloat
        if let notch = screen.notchSize {
            style = .notch(width: notch.width, height: notch.height)
            top = 0
            camera = notch.height
        } else {
            style = .pill
            top = 4
            camera = 0
        }

        let scene = NotchScene(size: frame.size,
                               trash: local(CGPoint(x: trash.frame.midX, y: trash.frame.midY)),
                               trashIconSize: trash.frame.width,
                               away: away,
                               peeksTrash: trash.isAutoHidden,
                               style: style,
                               top: top,
                               centerX: frame.width / 2,
                               cameraHeight: camera)
        return (frame, scene)
    }
}

extension NSScreen {
    /// The camera housing's size, on MacBooks that have one. It is always
    /// centered, between the two strips of menu bar beside it.
    var notchSize: CGSize? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea
        else { return nil }
        return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
    }
}
