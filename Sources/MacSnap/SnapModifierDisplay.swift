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
