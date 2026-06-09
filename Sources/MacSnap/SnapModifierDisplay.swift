import MacSnapCore

extension SnapModifier {
    var menuDisplayName: String {
        switch self {
        case .shift:
            "⇧ Shift"
        case .option:
            "⌥ Option"
        case .control:
            "⌃ Control"
        case .command:
            "⌘ Command"
        case .middleClick, .rightClick:
            displayName
        }
    }
}

extension KeyboardShortcut {
    var menuDisplayName: String {
        let parts = displayName.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else {
            return displayName
        }

        let keyName = parts.last ?? ""
        let modifierSymbols = parts.dropLast().map { part in
            switch part {
            case "Shift":
                "⇧"
            case "Option":
                "⌥"
            case "Control", "Ctrl":
                "⌃"
            case "Command":
                "⌘"
            default:
                "\(part)+"
            }
        }.joined()

        return modifierSymbols + keyName
    }
}
