import Foundation
import Carbon

public enum SnapModifier: String, CaseIterable, Equatable, Sendable {
    case shift
    case option
    case control
    case command
    case middleClick
    case rightClick

    public var displayName: String {
        switch self {
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .command: "Command"
        case .middleClick: "Middle Click"
        case .rightClick: "Right Click"
        }
    }
}

public struct GridSettings: Equatable, Sendable {
    public var rows: Int
    public var columns: Int
    public var gap: Int
    public var snapModifier: SnapModifier
    public var alternateSnapModifier: SnapModifier?
    public var spanModifier: SnapModifier
    public var alternateSpanModifier: SnapModifier?
    public var useVisibleFrame: Bool
    public var restoreSizeOnUnsnap: Bool
    public var appearance: GridAppearance

    public init(
        rows: Int,
        columns: Int,
        gap: Int,
        snapModifier: SnapModifier,
        alternateSnapModifier: SnapModifier? = nil,
        spanModifier: SnapModifier,
        alternateSpanModifier: SnapModifier? = nil,
        useVisibleFrame: Bool,
        restoreSizeOnUnsnap: Bool,
        appearance: GridAppearance
    ) {
        self.rows = rows
        self.columns = columns
        self.gap = gap
        self.snapModifier = snapModifier
        self.alternateSnapModifier = alternateSnapModifier
        self.spanModifier = spanModifier
        self.alternateSpanModifier = alternateSpanModifier
        self.useVisibleFrame = useVisibleFrame
        self.restoreSizeOnUnsnap = restoreSizeOnUnsnap
        self.appearance = appearance
    }
}

public struct GridColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct GridAppearance: Codable, Equatable, Sendable {
    public var backgroundColor: GridColor
    public var gridLineColor: GridColor
    public var selectionColor: GridColor

    public init(backgroundColor: GridColor, gridLineColor: GridColor, selectionColor: GridColor) {
        self.backgroundColor = backgroundColor
        self.gridLineColor = gridLineColor
        self.selectionColor = selectionColor
    }
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public func normalized() -> KeyboardShortcut {
        KeyboardShortcut(
            keyCode: keyCode,
            modifiers: modifiers,
            displayName: Self.displayName(keyCode: keyCode, modifiers: modifiers, fallback: displayName)
        )
    }

    fileprivate static func controlOptionDigit(_ digit: Int) -> KeyboardShortcut? {
        let keyCode: UInt32?
        switch digit {
        case 1: keyCode = 18
        case 2: keyCode = 19
        case 3: keyCode = 20
        case 4: keyCode = 21
        case 5: keyCode = 23
        case 6: keyCode = 22
        case 7: keyCode = 26
        case 8: keyCode = 28
        case 9: keyCode = 25
        default: keyCode = nil
        }

        guard let keyCode else {
            return nil
        }

        return KeyboardShortcut(
            keyCode: keyCode,
            modifiers: 6144,
            displayName: "Ctrl+Option+\(digit)"
        )
    }

    private static func displayName(keyCode: UInt32, modifiers: UInt32, fallback: String) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }

        parts.append(keyName(keyCode: keyCode, fallback: fallback))
        return parts.filter { !$0.isEmpty }.joined(separator: "+")
    }

    private static func keyName(keyCode: UInt32, fallback: String) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
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
            fallback.split(separator: "+").last.map(String.init) ?? "Key \(keyCode)"
        }
    }
}

public struct GridProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var rows: Int
    public var columns: Int
    public var gap: Int
    public var shortcut: KeyboardShortcut?

    public init(
        id: UUID = UUID(),
        name: String,
        rows: Int,
        columns: Int,
        gap: Int,
        shortcut: KeyboardShortcut? = nil
    ) {
        self.id = id
        self.name = name
        self.rows = rows
        self.columns = columns
        self.gap = gap
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case rows
        case columns
        case gap
        case shortcut
        case shortcutDigit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rows = try container.decode(Int.self, forKey: .rows)
        columns = try container.decode(Int.self, forKey: .columns)
        gap = try container.decode(Int.self, forKey: .gap)
        shortcut = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcut)

        if shortcut == nil,
           let shortcutDigit = try container.decodeIfPresent(Int.self, forKey: .shortcutDigit) {
            shortcut = KeyboardShortcut.controlOptionDigit(shortcutDigit)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rows, forKey: .rows)
        try container.encode(columns, forKey: .columns)
        try container.encode(gap, forKey: .gap)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
    }
}

public struct DisplayProfileAssignment: Codable, Equatable, Identifiable, Sendable {
    public var displayID: String
    public var displayName: String
    public var profileID: UUID

    public var id: String {
        displayID
    }

    public init(displayID: String, displayName: String, profileID: UUID) {
        self.displayID = displayID
        self.displayName = displayName
        self.profileID = profileID
    }
}

public final class SettingsStore {
    private enum Key {
        static let rows = "gridRows"
        static let columns = "gridColumns"
        static let gap = "gridGap"
        static let profiles = "gridProfiles"
        static let activeProfileID = "activeProfileID"
        static let displayProfileAssignments = "displayProfileAssignments"
        static let snapModifier = "snapModifier"
        static let alternateSnapModifier = "alternateSnapModifier"
        static let spanModifier = "spanModifier"
        static let alternateSpanModifier = "alternateSpanModifier"
        static let useVisibleFrame = "useVisibleFrame"
        static let restoreSizeOnUnsnap = "restoreSizeOnUnsnap"
        static let launchAtLogin = "launchAtLogin"
        static let gridAppearance = "gridAppearance"
    }

    public static let defaultSettings = GridSettings(
        rows: 2,
        columns: 4,
        gap: 0,
        snapModifier: .shift,
        alternateSnapModifier: nil,
        spanModifier: .middleClick,
        alternateSpanModifier: nil,
        useVisibleFrame: true,
        restoreSizeOnUnsnap: true,
        appearance: GridAppearance(
            backgroundColor: GridColor(red: 0, green: 0, blue: 0, alpha: 0.10),
            gridLineColor: GridColor(red: 1, green: 1, blue: 1, alpha: 0.64),
            selectionColor: GridColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 0.34)
        )
    )

    public static let defaultProfile = GridProfile(
        id: UUID(uuidString: "4A1B5C13-2B44-4B8E-8459-E0E6A4268D3B")!,
        name: "Default",
        rows: 2,
        columns: 4,
        gap: 0,
        shortcut: nil
    )

    private let defaults: UserDefaults
    private let validGridRange = 1...12
    private let validGapRange = 0...80
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ensureDefaults()
    }

    public var settings: GridSettings {
        get {
            settings(for: activeProfile)
        }
        set {
            rows = newValue.rows
            columns = newValue.columns
            gap = newValue.gap
            snapModifier = newValue.snapModifier
            alternateSnapModifier = newValue.alternateSnapModifier
            spanModifier = newValue.spanModifier
            alternateSpanModifier = newValue.alternateSpanModifier
            useVisibleFrame = newValue.useVisibleFrame
            restoreSizeOnUnsnap = newValue.restoreSizeOnUnsnap
            appearance = newValue.appearance
        }
    }

    public func settings(forDisplayID displayID: String?) -> GridSettings {
        guard let displayID,
              let profile = profile(forDisplayID: displayID)
        else {
            return settings
        }

        return settings(for: profile)
    }

    public var rows: Int {
        get {
            activeProfile.rows
        }
        set {
            updateActiveProfile { profile in
                profile.rows = clamp(newValue, to: validGridRange)
            }
        }
    }

    public var columns: Int {
        get {
            activeProfile.columns
        }
        set {
            updateActiveProfile { profile in
                profile.columns = clamp(newValue, to: validGridRange)
            }
        }
    }

    public var gap: Int {
        get {
            activeProfile.gap
        }
        set {
            updateActiveProfile { profile in
                profile.gap = clamp(newValue, to: validGapRange)
            }
        }
    }

    public var profiles: [GridProfile] {
        get {
            loadProfiles()
        }
        set {
            saveProfiles(newValue)
        }
    }

    public var activeProfileID: UUID {
        get {
            ensureProfilesExist()

            if let rawValue = defaults.string(forKey: Key.activeProfileID),
               let id = UUID(uuidString: rawValue),
               profiles.contains(where: { $0.id == id }) {
                return id
            }

            let fallback = profiles.first?.id ?? Self.defaultProfile.id
            defaults.set(fallback.uuidString, forKey: Key.activeProfileID)
            return fallback
        }
        set {
            guard profiles.contains(where: { $0.id == newValue }) else {
                return
            }

            defaults.set(newValue.uuidString, forKey: Key.activeProfileID)
        }
    }

    public var activeProfile: GridProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? Self.defaultProfile
    }

    public var displayProfileAssignments: [DisplayProfileAssignment] {
        get {
            loadDisplayProfileAssignments()
        }
        set {
            saveDisplayProfileAssignments(newValue)
        }
    }

    public func displayProfileAssignment(forDisplayID displayID: String) -> DisplayProfileAssignment? {
        displayProfileAssignments.first { $0.displayID == displayID }
    }

    public func profileID(forDisplayID displayID: String) -> UUID? {
        guard let assignment = displayProfileAssignment(forDisplayID: displayID),
              profiles.contains(where: { $0.id == assignment.profileID })
        else {
            return nil
        }

        return assignment.profileID
    }

    public func profile(forDisplayID displayID: String) -> GridProfile? {
        guard let profileID = profileID(forDisplayID: displayID) else {
            return nil
        }

        return profiles.first { $0.id == profileID }
    }

    public func setProfile(_ profileID: UUID?, forDisplayID displayID: String, displayName: String) {
        let sanitizedDisplayID = displayID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedDisplayID.isEmpty else {
            return
        }

        var assignments = displayProfileAssignments.filter { $0.displayID != sanitizedDisplayID }
        guard let profileID else {
            displayProfileAssignments = assignments
            return
        }

        guard profiles.contains(where: { $0.id == profileID }) else {
            return
        }

        let sanitizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        assignments.append(DisplayProfileAssignment(
            displayID: sanitizedDisplayID,
            displayName: sanitizedDisplayName.isEmpty ? "Display" : sanitizedDisplayName,
            profileID: profileID
        ))
        displayProfileAssignments = assignments
    }

    public func addProfile() -> GridProfile {
        let existingProfiles = profiles
        let base = activeProfile
        let profile = GridProfile(
            name: nextProfileName(existingProfiles),
            rows: base.rows,
            columns: base.columns,
            gap: base.gap
        )

        profiles = existingProfiles + [profile]
        activeProfileID = profile.id
        return profile
    }

    public func deleteActiveProfile() {
        deleteProfile(id: activeProfileID)
    }

    public func deleteProfile(id: UUID) {
        var updatedProfiles = profiles
        guard updatedProfiles.count > 1,
              let index = updatedProfiles.firstIndex(where: { $0.id == id })
        else {
            return
        }

        updatedProfiles.remove(at: index)
        profiles = updatedProfiles

        if activeProfileID == id {
            activeProfileID = updatedProfiles[min(index, updatedProfiles.count - 1)].id
        }
    }

    public func moveProfile(id: UUID, by offset: Int) {
        guard offset != 0 else {
            return
        }

        var updatedProfiles = profiles
        guard let sourceIndex = updatedProfiles.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = min(max(sourceIndex + offset, 0), updatedProfiles.count - 1)
        guard destinationIndex != sourceIndex else {
            return
        }

        let profile = updatedProfiles.remove(at: sourceIndex)
        updatedProfiles.insert(profile, at: destinationIndex)
        profiles = updatedProfiles
    }

    public func updateProfile(_ updatedProfile: GridProfile) {
        var updatedProfiles = profiles
        guard let index = updatedProfiles.firstIndex(where: { $0.id == updatedProfile.id }) else {
            return
        }

        updatedProfiles[index] = updatedProfile

        if let shortcut = updatedProfile.shortcut {
            for profileIndex in updatedProfiles.indices where updatedProfiles[profileIndex].id != updatedProfile.id {
                if updatedProfiles[profileIndex].shortcut == shortcut {
                    updatedProfiles[profileIndex].shortcut = nil
                }
            }
        }

        profiles = updatedProfiles
    }

    public func renameActiveProfile(_ name: String) {
        updateActiveProfile { profile in
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.name = trimmedName.isEmpty ? "Profile" : trimmedName
        }
    }

    public func setActiveProfileShortcut(_ shortcut: KeyboardShortcut?) {
        updateActiveProfile { profile in
            profile.shortcut = shortcut
        }

        guard let shortcut else {
            return
        }

        let activeID = activeProfileID
        var updatedProfiles = profiles
        for index in updatedProfiles.indices where updatedProfiles[index].id != activeID {
            if updatedProfiles[index].shortcut == shortcut {
                updatedProfiles[index].shortcut = nil
            }
        }
        profiles = updatedProfiles
    }

    public var snapModifier: SnapModifier {
        get {
            guard let rawValue = defaults.string(forKey: Key.snapModifier),
                  let modifier = SnapModifier(rawValue: rawValue)
            else {
                return Self.defaultSettings.snapModifier
            }

            return modifier
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.snapModifier)
            if newValue == spanModifier {
                spanModifier = Self.fallbackSpanModifier(for: newValue)
            }
            sanitizeOptionalModifiers()
        }
    }

    public var alternateSnapModifier: SnapModifier? {
        get {
            let modifier = rawOptionalModifier(for: Key.alternateSnapModifier)
            guard let modifier,
                  modifier != snapModifier,
                  modifier != spanModifier
            else {
                return nil
            }

            return modifier
        }
        set {
            guard let newValue,
                  newValue != snapModifier,
                  newValue != spanModifier
            else {
                defaults.removeObject(forKey: Key.alternateSnapModifier)
                return
            }

            defaults.set(newValue.rawValue, forKey: Key.alternateSnapModifier)
            if rawOptionalModifier(for: Key.alternateSpanModifier) == newValue {
                defaults.removeObject(forKey: Key.alternateSpanModifier)
            }
        }
    }

    public var spanModifier: SnapModifier {
        get {
            guard let rawValue = defaults.string(forKey: Key.spanModifier),
                  let modifier = SnapModifier(rawValue: rawValue),
                  modifier != snapModifier
            else {
                return Self.fallbackSpanModifier(for: snapModifier)
            }

            return modifier
        }
        set {
            let sanitizedValue = newValue == snapModifier
                ? Self.fallbackSpanModifier(for: snapModifier)
                : newValue
            defaults.set(sanitizedValue.rawValue, forKey: Key.spanModifier)
            sanitizeOptionalModifiers()
        }
    }

    public var alternateSpanModifier: SnapModifier? {
        get {
            let modifier = rawOptionalModifier(for: Key.alternateSpanModifier)
            guard let modifier,
                  modifier != spanModifier,
                  modifier != snapModifier
            else {
                return nil
            }

            return modifier
        }
        set {
            guard let newValue,
                  newValue != spanModifier,
                  newValue != snapModifier
            else {
                defaults.removeObject(forKey: Key.alternateSpanModifier)
                return
            }

            defaults.set(newValue.rawValue, forKey: Key.alternateSpanModifier)
            if rawOptionalModifier(for: Key.alternateSnapModifier) == newValue {
                defaults.removeObject(forKey: Key.alternateSnapModifier)
            }
        }
    }

    public var useVisibleFrame: Bool {
        get {
            boolValue(for: Key.useVisibleFrame, fallback: Self.defaultSettings.useVisibleFrame)
        }
        set {
            defaults.set(newValue, forKey: Key.useVisibleFrame)
        }
    }

    public var restoreSizeOnUnsnap: Bool {
        get {
            boolValue(for: Key.restoreSizeOnUnsnap, fallback: Self.defaultSettings.restoreSizeOnUnsnap)
        }
        set {
            defaults.set(newValue, forKey: Key.restoreSizeOnUnsnap)
        }
    }

    public var launchAtLogin: Bool {
        get {
            boolValue(for: Key.launchAtLogin, fallback: true)
        }
        set {
            defaults.set(newValue, forKey: Key.launchAtLogin)
        }
    }

    public var appearance: GridAppearance {
        get {
            guard let data = defaults.data(forKey: Key.gridAppearance),
                  let decodedAppearance = try? JSONDecoder().decode(GridAppearance.self, from: data)
            else {
                return Self.defaultSettings.appearance
            }

            return sanitize(decodedAppearance)
        }
        set {
            saveAppearance(newValue)
        }
    }

    public func reset() {
        profiles = [Self.defaultProfile]
        activeProfileID = Self.defaultProfile.id
        settings = Self.defaultSettings
        launchAtLogin = true
        displayProfileAssignments = []
    }

    private func ensureDefaults() {
        defaults.register(defaults: [
            Key.rows: Self.defaultSettings.rows,
            Key.columns: Self.defaultSettings.columns,
            Key.gap: Self.defaultSettings.gap,
            Key.snapModifier: Self.defaultSettings.snapModifier.rawValue,
            Key.spanModifier: Self.defaultSettings.spanModifier.rawValue,
            Key.useVisibleFrame: Self.defaultSettings.useVisibleFrame,
            Key.restoreSizeOnUnsnap: Self.defaultSettings.restoreSizeOnUnsnap,
            Key.launchAtLogin: true
        ])
        if defaults.data(forKey: Key.gridAppearance) == nil {
            saveAppearance(Self.defaultSettings.appearance)
        }
        ensureProfilesExist()
    }

    private static func fallbackSpanModifier(for snapModifier: SnapModifier) -> SnapModifier {
        if snapModifier != .middleClick {
            return .middleClick
        }

        return .option
    }

    private func sanitizeOptionalModifiers() {
        if let alternateSnap = rawOptionalModifier(for: Key.alternateSnapModifier),
           alternateSnap == snapModifier || alternateSnap == spanModifier {
            defaults.removeObject(forKey: Key.alternateSnapModifier)
        }

        if let alternateSpan = rawOptionalModifier(for: Key.alternateSpanModifier),
           alternateSpan == spanModifier || alternateSpan == snapModifier {
            defaults.removeObject(forKey: Key.alternateSpanModifier)
        }

        if let alternateSnap = rawOptionalModifier(for: Key.alternateSnapModifier),
           let alternateSpan = rawOptionalModifier(for: Key.alternateSpanModifier),
           alternateSnap == alternateSpan {
            defaults.removeObject(forKey: Key.alternateSpanModifier)
        }
    }

    private func ensureProfilesExist() {
        guard defaults.data(forKey: Key.profiles) == nil else {
            return
        }

        let migratedProfile = GridProfile(
            id: Self.defaultProfile.id,
            name: Self.defaultProfile.name,
            rows: intValue(for: Key.rows, fallback: Self.defaultSettings.rows, range: validGridRange),
            columns: intValue(for: Key.columns, fallback: Self.defaultSettings.columns, range: validGridRange),
            gap: intValue(for: Key.gap, fallback: Self.defaultSettings.gap, range: validGapRange),
            shortcut: Self.defaultProfile.shortcut
        )

        saveProfiles([migratedProfile])
        defaults.set(migratedProfile.id.uuidString, forKey: Key.activeProfileID)
    }

    private func loadProfiles() -> [GridProfile] {
        guard let data = defaults.data(forKey: Key.profiles),
              let decodedProfiles = try? JSONDecoder().decode([GridProfile].self, from: data)
        else {
            return [Self.defaultProfile]
        }

        let sanitizedProfiles = sanitize(decodedProfiles)
        if sanitizedProfiles != decodedProfiles {
            saveProfiles(sanitizedProfiles)
        }

        return sanitizedProfiles
    }

    private func saveProfiles(_ profiles: [GridProfile]) {
        let sanitizedProfiles = sanitize(profiles)
        guard let data = try? JSONEncoder().encode(sanitizedProfiles) else {
            return
        }

        defaults.set(data, forKey: Key.profiles)

        if !sanitizedProfiles.contains(where: { $0.id == activeProfileID }) {
            defaults.set(sanitizedProfiles[0].id.uuidString, forKey: Key.activeProfileID)
        }

        sanitizeDisplayProfileAssignments(validProfileIDs: Set(sanitizedProfiles.map(\.id)))
    }

    private func settings(for profile: GridProfile) -> GridSettings {
        GridSettings(
            rows: profile.rows,
            columns: profile.columns,
            gap: profile.gap,
            snapModifier: snapModifier,
            alternateSnapModifier: alternateSnapModifier,
            spanModifier: spanModifier,
            alternateSpanModifier: alternateSpanModifier,
            useVisibleFrame: useVisibleFrame,
            restoreSizeOnUnsnap: restoreSizeOnUnsnap,
            appearance: appearance
        )
    }

    private func loadDisplayProfileAssignments() -> [DisplayProfileAssignment] {
        guard let data = defaults.data(forKey: Key.displayProfileAssignments),
              let decodedAssignments = try? JSONDecoder().decode([DisplayProfileAssignment].self, from: data)
        else {
            return []
        }

        let sanitizedAssignments = sanitize(decodedAssignments, validProfileIDs: Set(profiles.map(\.id)))
        if sanitizedAssignments != decodedAssignments {
            saveDisplayProfileAssignments(sanitizedAssignments)
        }

        return sanitizedAssignments
    }

    private func saveDisplayProfileAssignments(_ assignments: [DisplayProfileAssignment]) {
        let sanitizedAssignments = sanitize(assignments, validProfileIDs: Set(profiles.map(\.id)))
        guard let data = try? JSONEncoder().encode(sanitizedAssignments) else {
            return
        }

        defaults.set(data, forKey: Key.displayProfileAssignments)
    }

    private func sanitizeDisplayProfileAssignments(validProfileIDs: Set<UUID>) {
        let assignments = displayProfileAssignments
        let sanitizedAssignments = sanitize(assignments, validProfileIDs: validProfileIDs)
        guard sanitizedAssignments != assignments else {
            return
        }

        guard let data = try? JSONEncoder().encode(sanitizedAssignments) else {
            return
        }

        defaults.set(data, forKey: Key.displayProfileAssignments)
    }

    private func updateActiveProfile(_ update: (inout GridProfile) -> Void) {
        var updatedProfiles = profiles
        let activeID = activeProfileID

        guard let index = updatedProfiles.firstIndex(where: { $0.id == activeID }) else {
            return
        }

        update(&updatedProfiles[index])
        profiles = updatedProfiles
    }

    private func sanitize(_ profiles: [GridProfile]) -> [GridProfile] {
        let sourceProfiles = profiles.isEmpty ? [Self.defaultProfile] : profiles

        return sourceProfiles.enumerated().map { index, profile in
            var sanitizedProfile = profile
            let trimmedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            sanitizedProfile.name = trimmedName.isEmpty ? "Profile \(index + 1)" : trimmedName
            sanitizedProfile.rows = clamp(profile.rows, to: validGridRange)
            sanitizedProfile.columns = clamp(profile.columns, to: validGridRange)
            sanitizedProfile.gap = clamp(profile.gap, to: validGapRange)

            if let shortcut = profile.shortcut?.normalized(),
               shortcut.keyCode > 0,
               shortcut.modifiers > 0,
               !shortcut.displayName.isEmpty {
                sanitizedProfile.shortcut = shortcut
            } else {
                sanitizedProfile.shortcut = nil
            }

            return sanitizedProfile
        }
    }

    private func sanitize(
        _ assignments: [DisplayProfileAssignment],
        validProfileIDs: Set<UUID>
    ) -> [DisplayProfileAssignment] {
        var seenDisplayIDs = Set<String>()

        return assignments.compactMap { assignment in
            let displayID = assignment.displayID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayID.isEmpty,
                  validProfileIDs.contains(assignment.profileID),
                  !seenDisplayIDs.contains(displayID)
            else {
                return nil
            }

            seenDisplayIDs.insert(displayID)
            let displayName = assignment.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return DisplayProfileAssignment(
                displayID: displayID,
                displayName: displayName.isEmpty ? "Display" : displayName,
                profileID: assignment.profileID
            )
        }
    }

    private func saveAppearance(_ appearance: GridAppearance) {
        guard let data = try? JSONEncoder().encode(sanitize(appearance)) else {
            return
        }

        defaults.set(data, forKey: Key.gridAppearance)
    }

    private func sanitize(_ appearance: GridAppearance) -> GridAppearance {
        GridAppearance(
            backgroundColor: sanitize(appearance.backgroundColor),
            gridLineColor: sanitize(appearance.gridLineColor),
            selectionColor: sanitize(appearance.selectionColor)
        )
    }

    private func sanitize(_ color: GridColor) -> GridColor {
        GridColor(
            red: clamp(color.red, to: 0...1),
            green: clamp(color.green, to: 0...1),
            blue: clamp(color.blue, to: 0...1),
            alpha: clamp(color.alpha, to: 0...1)
        )
    }

    private func nextProfileName(_ profiles: [GridProfile]) -> String {
        var index = profiles.count + 1
        var name = "Profile \(index)"
        let existingNames = Set(profiles.map(\.name))

        while existingNames.contains(name) {
            index += 1
            name = "Profile \(index)"
        }

        return name
    }

    private func intValue(for key: String, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return clamp(defaults.integer(forKey: key), to: range)
    }

    private func boolValue(for key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return defaults.bool(forKey: key)
    }

    private func rawOptionalModifier(for key: String) -> SnapModifier? {
        guard let rawValue = defaults.string(forKey: key) else {
            return nil
        }

        return SnapModifier(rawValue: rawValue)
    }

    private func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
