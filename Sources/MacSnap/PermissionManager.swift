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

    @discardableResult
    static func resetAccessibilityPermission(bundleIdentifier: String) -> Bool {
        UserDefaults.standard.removeObject(forKey: didRequestAccessibilityPromptKey)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("MacSnap: Failed to reset Accessibility permission: \(error.localizedDescription)")
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            NSLog("MacSnap: tccutil reset failed with status \(process.terminationStatus). \(output)")
            return false
        }

        NSLog("MacSnap: Reset Accessibility permission for \(bundleIdentifier).")
        return true
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
