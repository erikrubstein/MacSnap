import Foundation
import ServiceManagement

enum LaunchAtLoginController {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                switch SMAppService.mainApp.status {
                case .enabled:
                    return
                case .requiresApproval:
                    NSLog("MacSnap: Launch at login is waiting for approval in System Settings.")
                    return
                case .notRegistered, .notFound:
                    try SMAppService.mainApp.register()
                @unknown default:
                    try SMAppService.mainApp.register()
                }
            } else {
                switch SMAppService.mainApp.status {
                case .enabled, .requiresApproval:
                    try SMAppService.mainApp.unregister()
                case .notRegistered, .notFound:
                    return
                @unknown default:
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("MacSnap: Failed to update launch at login setting: \(error.localizedDescription)")
        }
    }
}
