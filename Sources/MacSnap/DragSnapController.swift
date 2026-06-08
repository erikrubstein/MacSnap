import AppKit
import MacSnapCore

@MainActor
final class DragSnapController {
    private let settingsStore: SettingsStore
    private let snapper: WindowSnapper
    private let overlayController: GridOverlayController

    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var mouseButtonMonitor: Any?
    private var modifierMonitor: Any?

    private var candidateWindow: WindowSnapper.WindowTarget?
    private var activeScreen: NSScreen?
    private var activeSelection: GridSelection?
    private var lastHoveredCell: GridCell?
    private var spanAnchorCell: GridCell?
    private var isSpanSelectionModeActive = false
    private var wasSpanTriggerPressed = false
    private var isSnapModeActive = false

    init(
        settingsStore: SettingsStore,
        snapper: WindowSnapper,
        overlayController: GridOverlayController
    ) {
        self.settingsStore = settingsStore
        self.snapper = snapper
        self.overlayController = overlayController
    }

    func start() {
        guard mouseDownMonitor == nil,
              mouseDragMonitor == nil,
              mouseUpMonitor == nil,
              mouseButtonMonitor == nil,
              modifierMonitor == nil
        else {
            return
        }

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDown()
            }
        }
        mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDragged()
            }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseUp()
            }
        }
        mouseButtonMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp
        ]) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseButtonChanged()
            }
        }
        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            Task { @MainActor in
                self?.handleModifierChanged()
            }
        }
    }

    func stop() {
        removeMonitor(mouseDownMonitor)
        removeMonitor(mouseDragMonitor)
        removeMonitor(mouseUpMonitor)
        removeMonitor(mouseButtonMonitor)
        removeMonitor(modifierMonitor)
        mouseDownMonitor = nil
        mouseDragMonitor = nil
        mouseUpMonitor = nil
        mouseButtonMonitor = nil
        modifierMonitor = nil
        reset()
    }

    private func handleMouseDown() {
        reset()

        guard PermissionManager.isAccessibilityTrusted else {
            return
        }

        candidateWindow = snapper.windowTarget(at: NSEvent.mouseLocation)
            ?? snapper.currentFocusedWindowTarget(requireMouseInsideWindow: true)
    }

    private func handleMouseDragged() {
        let settings = settingsStore.settings
        guard isSnapTriggerPressed(settings) else {
            restoreSizeOnUnsnapIfNeeded(settings: settings)
            hideActiveOverlay()
            return
        }

        if candidateWindow == nil {
            candidateWindow = snapper.windowTarget(at: NSEvent.mouseLocation)
                ?? snapper.currentFocusedWindowTarget(requireMouseInsideWindow: false)
        }

        guard let candidateWindow else {
            hideActiveOverlay()
            return
        }

        guard hasWindowMoved(candidateWindow) else {
            if isSnapModeActive {
                hideActiveOverlay()
            }
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = screen(containing: mouseLocation) ?? activeScreen ?? NSScreen.main else {
            hideActiveOverlay()
            return
        }

        let screenSettings = settingsStore.settings(forDisplayID: DisplayIdentity(screen: screen).id)
        let frame = screenFrame(for: screen, settings: screenSettings)
        let model = GridModel(settings: screenSettings)
        guard let cell = model.cell(at: mouseLocation, in: frame) else {
            activeScreen = screen
            activeSelection = nil
            lastHoveredCell = nil
            overlayController.update(
                on: screen,
                model: model,
                selection: nil,
                appearance: screenSettings.appearance,
                in: frame
            )
            return
        }

        if activeScreen != screen {
            spanAnchorCell = nil
            lastHoveredCell = nil
        }

        let selection: GridSelection
        if isSpanSelectionModeActive {
            let anchor = spanAnchorCell ?? lastHoveredCell ?? cell
            spanAnchorCell = anchor
            selection = model.selection(from: anchor, to: cell)
        } else {
            spanAnchorCell = nil
            selection = GridSelection(cell: cell)
        }

        activeScreen = screen
        activeSelection = selection
        lastHoveredCell = cell
        isSnapModeActive = true
        overlayController.update(
            on: screen,
            model: model,
            selection: selection,
            appearance: screenSettings.appearance,
            in: frame
        )
    }

    private func handleMouseUp() {
        defer {
            reset()
        }

        guard isSnapModeActive,
              let candidateWindow,
              let activeScreen,
              let activeSelection
        else {
            return
        }

        let settings = settingsStore.settings(forDisplayID: DisplayIdentity(screen: activeScreen).id)
        guard isSnapTriggerPressed(settings) else {
            return
        }

        let frame = screenFrame(for: activeScreen, settings: settings)
        let model = GridModel(settings: settings)
        let targetRect = model.rect(for: activeSelection, in: frame)
        snapper.snap(candidateWindow, to: targetRect, within: frame)
    }

    private func handleModifierChanged() {
        handleTriggerChanged()
    }

    private func handleMouseButtonChanged() {
        handleTriggerChanged()
    }

    private func handleTriggerChanged() {
        let settings = settingsStore.settings
        let snapTriggerIsPressed = isSnapTriggerPressed(settings)
        let spanTriggerIsPressed = isSpanTriggerPressed(settings)
        defer {
            wasSpanTriggerPressed = spanTriggerIsPressed
        }

        guard isSnapModeActive else {
            if snapTriggerIsPressed, isLeftButtonPressed {
                handleMouseDragged()
            }
            return
        }

        if !snapTriggerIsPressed {
            hideActiveOverlay()
            return
        }

        if isLeftButtonPressed, spanTriggerIsPressed, !wasSpanTriggerPressed {
            toggleSpanSelectionMode()
        }

        if isLeftButtonPressed {
            handleMouseDragged()
        }
    }

    private func toggleSpanSelectionMode() {
        isSpanSelectionModeActive.toggle()
        if isSpanSelectionModeActive {
            spanAnchorCell = spanAnchorCell ?? lastHoveredCell
        } else {
            spanAnchorCell = nil
        }
    }

    private func hasWindowMoved(_ target: WindowSnapper.WindowTarget) -> Bool {
        guard let currentRect = snapper.currentRect(for: target) else {
            return false
        }

        return abs(currentRect.minX - target.initialRect.minX) >= 2 ||
            abs(currentRect.minY - target.initialRect.minY) >= 2
    }

    private func restoreSizeOnUnsnapIfNeeded(settings: GridSettings) {
        guard settings.restoreSizeOnUnsnap,
              let candidateWindow,
              hasWindowMoved(candidateWindow)
        else {
            return
        }

        _ = snapper.restorePreviousSizeIfNeeded(for: candidateWindow, anchoredAt: NSEvent.mouseLocation)
    }

    private func hideActiveOverlay() {
        activeScreen = nil
        activeSelection = nil
        lastHoveredCell = nil
        spanAnchorCell = nil
        isSpanSelectionModeActive = false
        isSnapModeActive = false
        overlayController.hide()
    }

    private func reset() {
        candidateWindow = nil
        activeScreen = nil
        activeSelection = nil
        lastHoveredCell = nil
        spanAnchorCell = nil
        isSpanSelectionModeActive = false
        wasSpanTriggerPressed = false
        isSnapModeActive = false
        overlayController.hide()
    }

    private var isMiddleButtonPressed: Bool {
        NSEvent.pressedMouseButtons & (1 << 2) != 0
    }

    private var isLeftButtonPressed: Bool {
        NSEvent.pressedMouseButtons & 1 != 0
    }

    private var isRightButtonPressed: Bool {
        NSEvent.pressedMouseButtons & (1 << 1) != 0
    }

    private func isTriggerPressed(_ modifier: SnapModifier) -> Bool {
        switch modifier {
        case .middleClick:
            return isMiddleButtonPressed
        case .rightClick:
            return isRightButtonPressed
        case .shift, .option, .control, .command:
            return NSEvent.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(modifier.eventFlag)
        }
    }

    private func isTriggerPressed(_ modifier: SnapModifier?) -> Bool {
        guard let modifier else {
            return false
        }

        return isTriggerPressed(modifier)
    }

    private func isSnapTriggerPressed(_ settings: GridSettings) -> Bool {
        isTriggerPressed(settings.snapModifier) || isTriggerPressed(settings.alternateSnapModifier)
    }

    private func isSpanTriggerPressed(_ settings: GridSettings) -> Bool {
        isTriggerPressed(settings.spanModifier) || isTriggerPressed(settings.alternateSpanModifier)
    }

    private func screenFrame(for screen: NSScreen, settings: GridSettings) -> CGRect {
        settings.useVisibleFrame ? screen.visibleFrame : screen.frame
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.visibleFrame.contains(point) || screen.frame.contains(point)
        }
    }

    private func removeMonitor(_ monitor: Any?) {
        guard let monitor else {
            return
        }

        NSEvent.removeMonitor(monitor)
    }
}

private extension SnapModifier {
    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .shift: .shift
        case .option: .option
        case .control: .control
        case .command: .command
        case .middleClick, .rightClick: []
        }
    }
}
