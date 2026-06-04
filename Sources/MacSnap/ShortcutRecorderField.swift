import AppKit
import Carbon
import MacSnapCore

@MainActor
final class ShortcutRecorderField: NSButton {
    var onShortcutRecorded: ((KeyboardShortcut) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private var currentShortcut: KeyboardShortcut?
    private var isRecording = false

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        alignment = .left
        target = self
        action = #selector(beginRecording)
        focusRingType = .default
        setShortcut(nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func setShortcut(_ shortcut: KeyboardShortcut?) {
        currentShortcut = shortcut
        title = shortcut?.displayName ?? "None"
    }

    @objc private func beginRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        title = "Press shortcut..."
        onRecordingChanged?(true)
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder, isRecording {
            cancelRecording()
        }
        return didResignFirstResponder
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let shortcut = KeyboardShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers(from: event.modifierFlags),
            displayName: displayName(for: event)
        )

        guard shortcut.keyCode > 0,
              shortcut.modifiers > 0,
              !shortcut.displayName.isEmpty
        else {
            NSSound.beep()
            return
        }

        currentShortcut = shortcut
        title = shortcut.displayName
        onShortcutRecorded?(shortcut)
        finishRecording()
        window?.makeFirstResponder(nil)
    }

    private func cancelRecording() {
        isRecording = false
        setShortcut(currentShortcut)
        onRecordingChanged?(false)
    }

    private func finishRecording() {
        isRecording = false
        onRecordingChanged?(false)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers = UInt32(0)

        if normalizedFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if normalizedFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if normalizedFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if normalizedFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    private func displayName(for event: NSEvent) -> String {
        var parts: [String] = []
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if normalizedFlags.contains(.control) {
            parts.append("Control")
        }
        if normalizedFlags.contains(.option) {
            parts.append("Option")
        }
        if normalizedFlags.contains(.shift) {
            parts.append("Shift")
        }
        if normalizedFlags.contains(.command) {
            parts.append("Command")
        }

        parts.append(keyName(for: event))
        return parts.filter { !$0.isEmpty }.joined(separator: "+")
    }

    private func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Space: "Space"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_Escape: "Escape"
        case kVK_LeftArrow: "Left"
        case kVK_RightArrow: "Right"
        case kVK_UpArrow: "Up"
        case kVK_DownArrow: "Down"
        case kVK_Home: "Home"
        case kVK_End: "End"
        case kVK_PageUp: "Page Up"
        case kVK_PageDown: "Page Down"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_0: "0"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default:
            event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
