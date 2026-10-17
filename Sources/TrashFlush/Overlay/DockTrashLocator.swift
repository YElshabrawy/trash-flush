import AppKit
import ApplicationServices

/// Where the Trash sits in the Dock, in AppKit screen coordinates (origin at
/// the bottom left of the main display).
struct DockTrash {
    enum Edge { case bottom, left, right }

    /// Where the icon sits while the Dock is showing, even if it is auto-hidden right now.
    var frame: CGRect
    var edge: Edge
    var screen: NSScreen
    var isAutoHidden: Bool
    /// Read from the Dock itself rather than estimated.
    var isExact: Bool
}

/// Finds the Trash icon in the Dock.
///
/// With Accessibility access it asks the Dock for the icon's exact frame.
/// Without it, it estimates the position from the Dock's settings (tile size,
/// pinned and running apps), which is usually within an icon or so.
@MainActor
enum DockTrashLocator {
    static var isPrecise: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that adds the app to the Accessibility list.
    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func locate() -> DockTrash? {
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let edge: DockTrash.Edge = switch dock?.string(forKey: "orientation") {
        case "left": .left
        case "right": .right
        default: .bottom
        }
        let hidden = dock?.bool(forKey: "autohide") ?? false
        if let frame = accessibilityFrame(),
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? screen(for: edge) {
            var frame = clamp(frame, to: screen.frame)
            if hidden { frame = shown(frame, edge: edge, screen: screen) }
            return DockTrash(frame: frame, edge: edge, screen: screen, isAutoHidden: hidden, isExact: true)
        }
        guard let screen = screen(for: edge) else { return nil }
        return DockTrash(frame: estimatedFrame(edge: edge, screen: screen, dock: dock), edge: edge, screen: screen,
                         isAutoHidden: hidden, isExact: false)
    }

    /// A hidden Dock reports its icons tucked against (or past) the screen
    /// edge. Moves the icon to where it sits when the Dock slides out.
    private static func shown(_ frame: CGRect, edge: DockTrash.Edge, screen: NSScreen) -> CGRect {
        var frame = frame
        let inset: CGFloat = 10
        switch edge {
        case .bottom: frame.origin.y = screen.frame.minY + inset
        case .left: frame.origin.x = screen.frame.minX + inset
        case .right: frame.origin.x = screen.frame.maxX - inset - frame.width
        }
        return frame
    }

    // MARK: Accessibility

    private static func accessibilityFrame() -> CGRect? {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.25)

        for list in children(of: app) {
            for item in children(of: list) where attribute(item, "AXSubrole") as? String == "AXTrashDockItem" {
                guard let origin = value(item, "AXPosition", .cgPoint, CGPoint.zero),
                      let size = value(item, "AXSize", .cgSize, CGSize.zero),
                      let primary = NSScreen.screens.first
                else { return nil }
                // Accessibility measures from the top left of the main display.
                return CGRect(x: origin.x, y: primary.frame.maxY - origin.y - size.height,
                              width: size.width, height: size.height)
            }
        }
        return nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, "AXChildren") as? [AXUIElement] ?? []
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }

    private static func value<T: BitwiseCopyable>(_ element: AXUIElement, _ name: String, _ type: AXValueType, _ initial: T) -> T? {
        guard let raw = attribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = initial
        return AXValueGetValue(unsafeDowncast(raw, to: AXValue.self), type, &result) ? result : nil
    }

    // MARK: Estimate

    /// The display whose usable area is cut by the Dock, or the main display.
    private static func screen(for edge: DockTrash.Edge) -> NSScreen? {
        NSScreen.screens.first { dockThickness(on: $0, edge: edge) > 0 } ?? NSScreen.screens.first
    }

    private static func dockThickness(on screen: NSScreen, edge: DockTrash.Edge) -> CGFloat {
        let full = screen.frame, visible = screen.visibleFrame
        return switch edge {
        case .bottom: visible.minY - full.minY
        case .left: visible.minX - full.minX
        case .right: full.maxX - visible.maxX
        }
    }

    /// The Dock is centered on its edge and the Trash is its last tile, so the
    /// Trash sits half a Dock length from the middle.
    private static func estimatedFrame(edge: DockTrash.Edge, screen: NSScreen, dock: UserDefaults?) -> CGRect {
        let storedTile = CGFloat(dock?.double(forKey: "tilesize") ?? 0)
        let tile = storedTile > 0 ? storedTile : 48
        let measured = dockThickness(on: screen, edge: edge)
        let thickness = measured > tile ? measured : tile + 20

        let (tiles, separators) = tileCount(dock)
        let length = CGFloat(tiles) * tile + CGFloat(separators) * tile * 0.5 + tile * 0.4
        let alongDock = length / 2 - tile * 0.7

        let full = screen.frame
        let center: CGPoint = switch edge {
        case .bottom: CGPoint(x: full.midX + alongDock, y: full.minY + thickness / 2)
        case .left: CGPoint(x: full.minX + thickness / 2, y: full.midY - alongDock)
        case .right: CGPoint(x: full.maxX - thickness / 2, y: full.midY - alongDock)
        }
        return CGRect(x: center.x - tile / 2, y: center.y - tile / 2, width: tile, height: tile)
    }

    /// Finder, pinned apps, running or recent apps, pinned folders, then the Trash.
    private static func tileCount(_ dock: UserDefaults?) -> (tiles: Int, separators: Int) {
        func bundleIDs(_ key: String) -> [String] {
            (dock?.array(forKey: key) as? [[String: Any]] ?? []).compactMap {
                ($0["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
            }
        }
        let pinned = Set(bundleIDs("persistent-apps"))
        let pinnedCount = dock?.array(forKey: "persistent-apps")?.count ?? 0
        let folders = dock?.array(forKey: "persistent-others")?.count ?? 0
        let showRecents = dock?.object(forKey: "show-recents") as? Bool ?? true

        var extra = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier))
        if showRecents { extra.formUnion(bundleIDs("recent-apps")) }
        extra.subtract(pinned)
        extra.remove("com.apple.finder")

        return (1 + pinnedCount + extra.count + folders + 1, extra.isEmpty ? 1 : 2)
    }

    private static func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var rect = rect
        rect.origin.x = min(max(rect.minX, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, bounds.minY), bounds.maxY - rect.height)
        return rect
    }
}
