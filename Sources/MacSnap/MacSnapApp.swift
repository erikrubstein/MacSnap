import AppKit
import ApplicationServices
import Carbon
import MacSnapCore
import Sparkle

@_silgen_name("_AXUIElementGetWindow")
private func AXUIElementGetWindowID(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

@main
@MainActor
final class MacSnapApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var profileHotKeyManager: HotKeyManager?
    private var settingsWindowController: SettingsWindowController?
    private var dragSnapController: DragSnapController?
    private var updaterController: SPUStandardUpdaterController?
    private let snapper = WindowSnapper()
    private let settingsStore = SettingsStore()
    private let overlayController = GridOverlayController()
    private let profilesMenuItem = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
    private let profilesMenu = NSMenu(title: "Profiles")
    private var flashTimer: Timer?
    private var lastKnownActiveProfileID: UUID?
    private var profileHotkeysSuspended = false

    static func main() {
        let app = NSApplication.shared
        let delegate = MacSnapApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        requestAccessibilityPermission()
        LaunchAtLoginController.setEnabled(settingsStore.launchAtLogin)
        lastKnownActiveProfileID = settingsStore.activeProfileID
        settingsWindowController = SettingsWindowController(
            store: settingsStore,
            onSettingsChanged: { [weak self] _, previewIntent in
                self?.handleSettingsChanged(previewIntent: previewIntent)
            },
            onLaunchAtLoginChanged: { enabled in
                LaunchAtLoginController.setEnabled(enabled)
            },
            onShortcutRecordingChanged: { [weak self] isRecording in
                self?.setProfileHotkeysSuspended(isRecording)
            }
        )
        dragSnapController = DragSnapController(
            settingsStore: settingsStore,
            snapper: snapper,
            overlayController: overlayController
        )
        dragSnapController?.start()

        if isUpdaterConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            NSLog("MacSnap: Sparkle updater is unavailable without packaged app metadata.")
        }
        configureProfileHotkeys()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        settingsWindowController?.reload()
    }

    private func setupMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = ""
        item.button?.image = menuBarIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "MacSnap"

        let menu = NSMenu()
        profilesMenuItem.submenu = profilesMenu
        menu.addItem(profilesMenuItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let versionItem = NSMenuItem(title: appVersionMenuTitle(), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = isUpdaterConfigured
        menu.addItem(updateItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
        refreshMenuState()
    }

    private func menuBarIcon() -> NSImage? {
        let imageURL = Bundle.main.url(forResource: "MacSnapIcon", withExtension: "svg", subdirectory: "MacSnap_MacSnap.bundle")
            ?? Bundle.module.url(forResource: "MacSnapIcon", withExtension: "svg")

        let image = imageURL.flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MacSnap")

        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        return image
    }

    private func appVersionMenuTitle() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, !build.isEmpty, build != version {
            return "Version \(version) (\(build))"
        }

        return "Version \(version)"
    }

    private var isUpdaterConfigured: Bool {
        bundleString("SUFeedURL") != nil && bundleString("SUPublicEDKey") != nil
    }

    private func bundleString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return value
    }

    private func requestAccessibilityPermission() {
        let trusted = PermissionManager.requestAccessibilityPermissionIfNeeded()
        if trusted {
            NSLog("MacSnap: Accessibility permission is already granted.")
        } else {
            NSLog("MacSnap: Accessibility permission is required before snapping will work. Open Settings to grant or refresh permission.")
        }
    }

    private func refreshMenuState() {
        rebuildProfilesMenu()
    }

    private func rebuildProfilesMenu() {
        profilesMenu.removeAllItems()

        for profile in settingsStore.profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(switchProfileFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.id.uuidString
            item.state = profile.id == settingsStore.activeProfileID ? .on : .off
            if let shortcut = profile.shortcut {
                item.toolTip = shortcut.displayName
            }
            profilesMenu.addItem(item)
        }
    }

    private func handleSettingsChanged(previewIntent: SettingsWindowController.PreviewIntent) {
        let activeProfileID = settingsStore.activeProfileID
        let didSwitchProfile = lastKnownActiveProfileID != nil
            && lastKnownActiveProfileID != activeProfileID

        lastKnownActiveProfileID = activeProfileID
        refreshMenuState()
        configureProfileHotkeys()

        switch previewIntent {
        case .sampleCell:
            flashGridLayout(selection: .sampleCell)
        case .profileSwitch where didSwitchProfile:
            flashGridLayout(selection: .none)
        case .profileSwitch, .none:
            break
        }
    }

    private func configureProfileHotkeys() {
        guard !profileHotkeysSuspended else {
            profileHotKeyManager?.unregisterAll()
            return
        }

        if profileHotKeyManager == nil {
            profileHotKeyManager = HotKeyManager()
        } else {
            profileHotKeyManager?.unregisterAll()
        }

        for profile in settingsStore.profiles {
            guard let shortcut = profile.shortcut else {
                continue
            }

            profileHotKeyManager?.register(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers,
                label: "Switch to profile '\(profile.name)'"
            ) { [weak self] in
                Task { @MainActor in
                    self?.switchToProfile(id: profile.id)
                }
            }
        }
    }

    private func setProfileHotkeysSuspended(_ isSuspended: Bool) {
        guard profileHotkeysSuspended != isSuspended else {
            return
        }

        profileHotkeysSuspended = isSuspended
        if isSuspended {
            profileHotKeyManager?.unregisterAll()
        } else {
            configureProfileHotkeys()
        }
    }

    private func switchToProfile(id: UUID) {
        settingsStore.activeProfileID = id
        lastKnownActiveProfileID = settingsStore.activeProfileID
        refreshMenuState()
        settingsWindowController?.reload()
        flashGridLayout(selection: .none)
    }

    @objc private func showSettings() {
        settingsWindowController?.showWindow(nil)
    }

    @objc private func switchProfileFromMenu(_ sender: NSMenuItem) {
        guard let rawID = sender.representedObject as? String,
              let id = UUID(uuidString: rawID)
        else {
            return
        }

        switchToProfile(id: id)
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        updaterController?.checkForUpdates(sender)
    }

    private func flashGridLayout(selection: OverlaySelectionMode) {
        flashTimer?.invalidate()
        _ = showCurrentGridOverlay(selection: selection)
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController.hide()
                self?.flashTimer = nil
            }
        }
    }

    private enum OverlaySelectionMode {
        case none
        case sampleCell
    }

    @discardableResult
    private func showCurrentGridOverlay(selection selectionMode: OverlaySelectionMode) -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = screen(containing: mouseLocation) ?? NSScreen.main else {
            overlayController.hide()
            return false
        }

        let settings = settingsStore.settings
        let frame = screenFrame(for: screen, settings: settings)
        let model = GridModel(settings: settings)
        let selection: GridSelection?
        switch selectionMode {
        case .none:
            selection = nil
        case .sampleCell:
            selection = GridSelection(cell: GridCell(row: settings.rows / 2, column: settings.columns / 2))
        }
        overlayController.update(
            on: screen,
            model: model,
            selection: selection,
            appearance: settings.appearance,
            in: frame
        )
        return true
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.visibleFrame.contains(point) || screen.frame.contains(point)
        }
    }

    private func screenFrame(for screen: NSScreen, settings: GridSettings) -> CGRect {
        settings.useVisibleFrame ? screen.visibleFrame : screen.frame
    }

    @objc private func quit() {
        dragSnapController?.stop()
        flashTimer?.invalidate()
        overlayController.hide()
        NSApp.terminate(nil)
    }
}

final class HotKeyManager {
    private struct Registration {
        let reference: EventHotKeyRef
        let action: () -> Void
        let label: String
    }

    private var nextID: UInt32 = 1
    private var registrations: [UInt32: Registration] = [:]
    private var eventHandler: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.reference)
        }

        registrations.removeAll()
    }

    func register(keyCode: UInt32, modifiers: UInt32, label: String, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: fourCharCode("GSNP"), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            NSLog("MacSnap: Failed to register hotkey '\(label)' with status \(status).")
            return
        }

        registrations[id] = Registration(reference: hotKeyRef, action: action, label: label)
        NSLog("MacSnap: Registered hotkey '\(label)'.")
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let manager = Unmanaged<HotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                manager.handleHotKey(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        if status != noErr {
            NSLog("MacSnap: Failed to install hotkey event handler with status \(status).")
        }
    }

    private func handleHotKey(id: UInt32) {
        guard let registration = registrations[id] else {
            NSLog("MacSnap: Ignoring unknown hotkey id \(id).")
            return
        }

        NSLog("MacSnap: \(registration.label)")
        registration.action()
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: UInt32 = 0

        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + scalar.value
        }

        return OSType(result)
    }
}

final class WindowSnapper {
    struct WindowTarget {
        let element: AXUIElement
        let processID: pid_t?
        let windowID: CGWindowID?
        let initialRect: CGRect
    }

    private struct SnappedWindowState {
        let originalRect: CGRect
        let snappedRect: CGRect
    }

    enum Target {
        case leftHalf
        case rightHalf
    }

    private var snappedWindowStates: [CGWindowID: SnappedWindowState] = [:]

    func snapFocusedWindow(to target: Target) {
        guard AXIsProcessTrusted() else {
            NSLog("MacSnap: Accessibility permission is missing.")
            return
        }

        guard let focusedWindow = focusedWindow() else {
            NSLog("MacSnap: No focused window found.")
            return
        }

        guard let screen = screenForFocusedWindow(focusedWindow) ?? NSScreen.main else {
            NSLog("MacSnap: No screen found.")
            return
        }

        let frame = screen.visibleFrame
        let targetRect: CGRect

        switch target {
        case .leftHalf:
            targetRect = CGRect(
                x: frame.minX,
                y: frame.minY,
                width: floor(frame.width / 2),
                height: frame.height
            )
        case .rightHalf:
            let width = floor(frame.width / 2)
            targetRect = CGRect(
                x: frame.maxX - width,
                y: frame.minY,
                width: width,
                height: frame.height
            )
        }

        _ = move(window: focusedWindow, to: targetRect)
    }

    func windowTarget(at point: CGPoint) -> WindowTarget? {
        guard PermissionManager.isAccessibilityTrusted else {
            NSLog("MacSnap: Accessibility permission is missing.")
            return nil
        }

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let ownPID = pid_t(ProcessInfo.processInfo.processIdentifier)

        for windowInfo in windowInfoList {
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ownPID,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID
            else {
                continue
            }

            if let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat, alpha <= 0 {
                continue
            }

            guard let element = axWindow(pid: pid, windowID: windowID),
                  let rect = rect(for: element),
                  rect.contains(point),
                  isResizable(element)
            else {
                continue
            }

            return WindowTarget(
                element: element,
                processID: pid,
                windowID: windowID,
                initialRect: rect
            )
        }

        return nil
    }

    func currentFocusedWindowTarget(requireMouseInsideWindow: Bool = false) -> WindowTarget? {
        guard PermissionManager.isAccessibilityTrusted else {
            NSLog("MacSnap: Accessibility permission is missing.")
            return nil
        }

        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        guard let window = focusedWindow(),
              let rect = rect(for: window),
              isResizable(window)
        else {
            return nil
        }

        if requireMouseInsideWindow, !rect.contains(NSEvent.mouseLocation) {
            return nil
        }

        return WindowTarget(
            element: window,
            processID: processID(for: window),
            windowID: windowID(for: window),
            initialRect: rect
        )
    }

    func snap(_ target: WindowTarget, to rect: CGRect, within bounds: CGRect? = nil) {
        let clampedRect = clamp(rect, to: bounds)

        if move(window: target.element, to: clampedRect) {
            rememberSnappedState(for: target, snappedRect: clampedRect)
            return
        }

        guard let pid = target.processID,
              let windowID = target.windowID,
              let freshElement = axWindow(pid: pid, windowID: windowID)
        else {
            return
        }

        NSLog("MacSnap: Retrying snap with a refreshed window reference.")
        if move(window: freshElement, to: clampedRect) {
            rememberSnappedState(for: target, snappedRect: clampedRect)
        }
    }

    func currentRect(for target: WindowTarget) -> CGRect? {
        if let rect = rect(for: target.element) {
            return rect
        }

        guard let pid = target.processID,
              let windowID = target.windowID,
              let freshElement = axWindow(pid: pid, windowID: windowID)
        else {
            return nil
        }

        return rect(for: freshElement)
    }

    func restorePreviousSizeIfNeeded(for target: WindowTarget, anchoredAt anchorPoint: CGPoint) -> Bool {
        guard let windowID = target.windowID,
              let state = snappedWindowStates[windowID],
              let currentRect = currentRect(for: target)
        else {
            return false
        }

        let xRatio = ratio(anchorPoint.x - currentRect.minX, in: currentRect.width)
        let yRatio = ratio(anchorPoint.y - currentRect.minY, in: currentRect.height)
        let restoredRect = CGRect(
            x: anchorPoint.x - (state.originalRect.width * xRatio),
            y: anchorPoint.y - (state.originalRect.height * yRatio),
            width: state.originalRect.width,
            height: state.originalRect.height
        )

        guard move(window: target.element, to: restoredRect) else {
            return false
        }

        snappedWindowStates.removeValue(forKey: windowID)
        NSLog("MacSnap: Restored unsnapped window size from \(state.snappedRect.size) to \(state.originalRect.size).")
        return true
    }

    private func ratio(_ value: CGFloat, in length: CGFloat) -> CGFloat {
        guard length > 0 else {
            return 0
        }

        return min(max(value / length, 0), 1)
    }

    private func rememberSnappedState(for target: WindowTarget, snappedRect: CGRect) {
        guard let windowID = target.windowID else {
            return
        }

        let existingOriginalRect = snappedWindowStates[windowID]?.originalRect
        snappedWindowStates[windowID] = SnappedWindowState(
            originalRect: existingOriginalRect ?? target.initialRect,
            snappedRect: snappedRect
        )
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success else {
            NSLog("MacSnap: Could not read focused window. AX error \(result.rawValue).")
            return nil
        }

        guard let focusedWindow = focusedWindow else {
            return nil
        }

        return (focusedWindow as! AXUIElement)
    }

    private func axWindow(pid: pid_t, windowID targetWindowID: CGWindowID) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement]
        else {
            return nil
        }

        for window in windows {
            guard isWindowRole(window),
                  windowID(for: window) == targetWindowID
            else {
                continue
            }

            return window
        }

        return nil
    }

    private func windowID(for window: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        let result = AXUIElementGetWindowID(window, &windowID)
        guard result == .success, windowID != 0 else {
            return nil
        }

        return windowID
    }

    private func processID(for window: AXUIElement) -> pid_t? {
        var pid = pid_t(0)
        let result = AXUIElementGetPid(window, &pid)
        guard result == .success, pid != 0 else {
            return nil
        }

        return pid
    }

    private func isWindowRole(_ window: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String,
              role == kAXWindowRole
        else {
            return false
        }

        return true
    }

    private func screenForFocusedWindow(_ window: AXUIElement) -> NSScreen? {
        guard let rect = rect(for: window) else {
            return nil
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    private func rect(for window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )
        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard positionResult == .success,
              sizeResult == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard CFGetTypeID(positionAXValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeAXValue) == AXValueGetTypeID()
        else {
            return nil
        }

        AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)

        return appKitRect(fromAXPosition: position, size: size)
    }

    private func move(window: AXUIElement, to rect: CGRect) -> Bool {
        guard isResizable(window) else {
            NSLog("MacSnap: Focused window is not resizable.")
            return false
        }

        var position = axPosition(for: rect)
        var size = rect.size

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            NSLog("MacSnap: Could not create AX values.")
            return false
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        if positionResult == .success, sizeResult == .success {
            NSLog("MacSnap: Snapped focused window to \(rect).")
            return true
        } else {
            NSLog(
                "MacSnap: Snap failed. Position AX error \(positionResult.rawValue), size AX error \(sizeResult.rawValue)."
            )
            return false
        }
    }

    private func isResizable(_ window: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(
            window,
            kAXSizeAttribute as CFString,
            &settable
        )

        return result == .success && settable.boolValue
    }

    private func axPosition(for appKitRect: CGRect) -> CGPoint {
        CGPoint(
            x: appKitRect.minX,
            y: desktopTopY - appKitRect.maxY
        )
    }

    private func appKitRect(fromAXPosition axPosition: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: axPosition.x,
            y: desktopTopY - axPosition.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private var desktopTopY: CGFloat {
        NSScreen.screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.maxY ?? 0
    }

    private func clamp(_ rect: CGRect, to bounds: CGRect?) -> CGRect {
        guard let bounds else {
            return rect
        }

        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
