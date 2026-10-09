import Foundation
import ServiceManagement

/// "Launch at login" through SMAppService, the modern API (macOS 13+). It only
/// works for a real .app bundle, not when running the bare binary from Xcode's
/// Swift package scheme.
@MainActor
enum LoginItem {
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            // The user may have to approve it once in System Settings.
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
