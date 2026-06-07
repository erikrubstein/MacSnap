import AppKit
import ApplicationServices

enum PermissionManager {
    private static let didRequestAccessibilityPromptKey = "didRequestAccessibilityPrompt"

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermissionIfNeeded() -> Bool {
        if isAccessibilityTrusted {
            return true
        }

        guard !UserDefaults.standard.bool(forKey: didRequestAccessibilityPromptKey) else {
            return false
        }

        UserDefaults.standard.set(true, forKey: didRequestAccessibilityPromptKey)

        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
