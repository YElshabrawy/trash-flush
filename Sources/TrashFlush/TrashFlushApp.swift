import AppKit
import SwiftUI

@main
struct TrashFlushApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: model.menuBarIcon.image)
                .accessibilityLabel("Trash Flush")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // The bundled app sets LSUIElement in Info.plist. This covers running the
        // bare binary from Xcode: menu bar only, no Dock icon.
        NSApp.setActivationPolicy(.accessory)    }
}

@MainActor
enum AppSymbol {
    /// "toilet" arrived in SF Symbols 4; fall back to a trash can just in case.
    static let toilet = NSImage(systemSymbolName: "toilet.fill", accessibilityDescription: nil) != nil
        ? "toilet.fill" : "trash.fill"
}
