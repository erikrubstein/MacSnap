import AppKit
import MacSnapCore

@MainActor
final class ProfileEditorWindowController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {
    private enum ShortcutRole {
        case defaultProfile
        case display
    }

    private var profile: GridProfile
    private let profilesProvider: () -> [GridProfile]
    private let overlayController: GridOverlayController
    private let settingsProvider: () -> GridSettings
    private let affectedScreensProvider: (UUID) -> [NSScreen]
    private let onShortcutRecordingChanged: (Bool) -> Void
    private let onSave: (GridProfile) -> Void
    private let labelWidth: CGFloat = 140
    private let controlSpacing: CGFloat = 12
    private let sliderWidth: CGFloat = 220
    private let valueLabelWidth: CGFloat = 32
    private let textFieldWidth: CGFloat = 250
    private let buttonRowWidth: CGFloat = 442
    private let rowHeight: CGFloat = 28

    private let nameField = NSTextField()
    private let rowsSlider = NSSlider()
    private let columnsSlider = NSSlider()
    private let gapSlider = NSSlider()
    private let rowsValueLabel = NSTextField(labelWithString: "")
    private let columnsValueLabel = NSTextField(labelWithString: "")
    private let gapValueLabel = NSTextField(labelWithString: "")
    private let defaultShortcutField = ShortcutRecorderField()
    private let displayShortcutField = ShortcutRecorderField()
    private var previewHideTimer: Timer?

    init(
        profile: GridProfile,
        profilesProvider: @escaping () -> [GridProfile],
        overlayController: GridOverlayController,
        settingsProvider: @escaping () -> GridSettings,
        affectedScreensProvider: @escaping (UUID) -> [NSScreen],
        onShortcutRecordingChanged: @escaping (Bool) -> Void,
        onSave: @escaping (GridProfile) -> Void
    ) {
        self.profile = profile
        self.profilesProvider = profilesProvider
        self.overlayController = overlayController
        self.settingsProvider = settingsProvider
        self.affectedScreensProvider = affectedScreensProvider
        self.onShortcutRecordingChanged = onShortcutRecordingChanged
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 310),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Profile"
        window.isReleasedWhenClosed = false
        window.level = GridOverlayController.appWindowLevel

        super.init(window: window)

        window.delegate = self
        window.contentView = makeContentView()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        previewHideTimer?.invalidate()
        overlayController.hide()
    }

    private func makeContentView() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeTextRow(label: "Name", field: nameField))
        stack.addArrangedSubview(makeSliderRow(label: "Rows", slider: rowsSlider, valueLabel: rowsValueLabel, min: 1, max: 12))
        stack.addArrangedSubview(makeSliderRow(label: "Columns", slider: columnsSlider, valueLabel: columnsValueLabel, min: 1, max: 12))
        stack.addArrangedSubview(makeSliderRow(label: "Gap", slider: gapSlider, valueLabel: gapValueLabel, min: 0, max: 80))
        stack.addArrangedSubview(makeShortcutRow(
            label: "Apply",
            field: displayShortcutField,
            role: .display,
            clearAction: #selector(clearDisplayShortcutClicked)
        ))
        stack.addArrangedSubview(makeShortcutRow(
            label: "Make Default",
            field: defaultShortcutField,
            role: .defaultProfile,
            clearAction: #selector(clearDefaultShortcutClicked)
        ))
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeButtonRow())

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        return container
    }

    private func makeTextRow(label: String, field: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = controlSpacing
        row.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: textFieldWidth).isActive = true
        field.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(field)

        return row
    }

    private func makeSliderRow(
        label: String,
        slider: NSSlider,
        valueLabel: NSTextField,
        min: Int,
        max: Int
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = controlSpacing
        row.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        slider.minValue = Double(min)
        slider.maxValue = Double(max)
        if max - min <= 12 {
            slider.numberOfTickMarks = max - min + 1
            slider.allowsTickMarkValuesOnly = true
        }
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true

        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: valueLabelWidth).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)

        return row
    }

    private func makeShortcutRow(
        label: String,
        field: ShortcutRecorderField,
        role: ShortcutRole,
        clearAction: Selector
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = controlSpacing
        row.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        field.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true
        field.onShortcutRecorded = { [weak self] shortcut in
            self?.handleRecordedShortcut(shortcut, role: role)
        }
        field.onRecordingChanged = { [weak self] isRecording in
            self?.onShortcutRecordingChanged(isRecording)
        }

        let clearButton = NSButton(title: "Clear", target: self, action: clearAction)

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(field)
        row.addArrangedSubview(clearButton)

        return row
    }

    private func makeButtonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.keyEquivalent = "\r"

        let spacer = NSView()
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(cancelButton)
        row.addArrangedSubview(saveButton)
        row.widthAnchor.constraint(equalToConstant: buttonRowWidth).isActive = true

        return row
    }

    private func refresh() {
        nameField.stringValue = profile.name
        rowsSlider.integerValue = profile.rows
        columnsSlider.integerValue = profile.columns
        gapSlider.integerValue = profile.gap
        refreshSliderLabels()
        defaultShortcutField.setShortcut(profile.defaultShortcut)
        displayShortcutField.setShortcut(profile.displayShortcut)
    }

    private func syncFromFields() {
        let trimmedName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = trimmedName.isEmpty ? "Profile" : trimmedName
        profile.rows = min(max(rowsSlider.integerValue, 1), 12)
        profile.columns = min(max(columnsSlider.integerValue, 1), 12)
        profile.gap = min(max(gapSlider.integerValue, 0), 80)
    }

    private func refreshSliderLabels() {
        rowsValueLabel.stringValue = "\(rowsSlider.integerValue)"
        columnsValueLabel.stringValue = "\(columnsSlider.integerValue)"
        gapValueLabel.stringValue = "\(gapSlider.integerValue)"
    }

    private func showGridOverlay() {
        let screens = affectedScreensProvider(profile.id)
        guard !screens.isEmpty else {
            overlayController.hide()
            return
        }

        let baseSettings = settingsProvider()
        let settings = GridSettings(
            rows: rowsSlider.integerValue,
            columns: columnsSlider.integerValue,
            gap: gapSlider.integerValue,
            snapModifier: baseSettings.snapModifier,
            alternateSnapModifier: baseSettings.alternateSnapModifier,
            spanModifier: baseSettings.spanModifier,
            alternateSpanModifier: baseSettings.alternateSpanModifier,
            useVisibleFrame: baseSettings.useVisibleFrame,
            restoreSizeOnUnsnap: baseSettings.restoreSizeOnUnsnap,
            appearance: baseSettings.appearance
        )

        for (index, screen) in screens.enumerated() {
            let frame = settings.useVisibleFrame ? screen.visibleFrame : screen.frame
            overlayController.update(
                on: screen,
                model: GridModel(settings: settings),
                selection: nil,
                appearance: settings.appearance,
                in: frame,
                replacingExisting: index == 0
            )
        }

        previewHideTimer?.invalidate()
        previewHideTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController.hide()
                self?.previewHideTimer = nil
            }
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        refreshSliderLabels()
        showGridOverlay()
    }

    @objc private func clearDefaultShortcutClicked() {
        profile.defaultShortcut = nil
        defaultShortcutField.setShortcut(nil)
    }

    @objc private func clearDisplayShortcutClicked() {
        profile.displayShortcut = nil
        displayShortcutField.setShortcut(nil)
    }

    @objc private func cancelClicked() {
        closeSheet()
    }

    @objc private func saveClicked() {
        syncFromFields()
        onSave(profile)
        closeSheet()
    }

    private func closeSheet() {
        onShortcutRecordingChanged(false)
        previewHideTimer?.invalidate()
        overlayController.hide()

        guard let window else {
            return
        }

        window.sheetParent?.endSheet(window)
    }

    private func handleRecordedShortcut(_ shortcut: KeyboardShortcut, role: ShortcutRole) {
        let normalizedShortcut = shortcut.normalized()
        if role == .defaultProfile,
           profile.displayShortcut?.normalized() == normalizedShortcut {
            profile.displayShortcut = nil
            displayShortcutField.setShortcut(nil)
        }
        if role == .display,
           profile.defaultShortcut?.normalized() == normalizedShortcut {
            profile.defaultShortcut = nil
            defaultShortcutField.setShortcut(nil)
        }

        guard let conflict = shortcutConflict(for: normalizedShortcut) else {
            setShortcut(normalizedShortcut, for: role)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Replace Shortcut?"
        alert.informativeText = "\(normalizedShortcut.menuDisplayName) is already assigned to \(conflict). Replace it?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            setShortcut(normalizedShortcut, for: role)
        } else {
            refreshShortcutFields()
        }
    }

    private func setShortcut(_ shortcut: KeyboardShortcut, for role: ShortcutRole) {
        switch role {
        case .defaultProfile:
            profile.defaultShortcut = shortcut
            defaultShortcutField.setShortcut(shortcut)
        case .display:
            profile.displayShortcut = shortcut
            displayShortcutField.setShortcut(shortcut)
        }
    }

    private func refreshShortcutFields() {
        defaultShortcutField.setShortcut(profile.defaultShortcut)
        displayShortcutField.setShortcut(profile.displayShortcut)
    }

    private func shortcutConflict(for shortcut: KeyboardShortcut) -> String? {
        for otherProfile in profilesProvider() where otherProfile.id != profile.id {
            if otherProfile.defaultShortcut?.normalized() == shortcut {
                return "\"\(otherProfile.name)\" Make Default"
            }
            if otherProfile.displayShortcut?.normalized() == shortcut {
                return "\"\(otherProfile.name)\" Apply"
            }
        }

        return nil
    }
}
