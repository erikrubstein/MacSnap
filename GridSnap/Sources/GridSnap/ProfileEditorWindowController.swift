import AppKit
import GridSnapCore

@MainActor
final class ProfileEditorWindowController: NSWindowController, NSTextFieldDelegate {
    private var profile: GridProfile
    private let profilesProvider: () -> [GridProfile]
    private let onShortcutRecordingChanged: (Bool) -> Void
    private let onSave: (GridProfile) -> Void

    private let nameField = NSTextField()
    private let rowsSlider = NSSlider()
    private let columnsSlider = NSSlider()
    private let gapSlider = NSSlider()
    private let rowsValueLabel = NSTextField(labelWithString: "")
    private let columnsValueLabel = NSTextField(labelWithString: "")
    private let gapValueLabel = NSTextField(labelWithString: "")
    private let shortcutField = ShortcutRecorderField()

    init(
        profile: GridProfile,
        profilesProvider: @escaping () -> [GridProfile],
        onShortcutRecordingChanged: @escaping (Bool) -> Void,
        onSave: @escaping (GridProfile) -> Void
    ) {
        self.profile = profile
        self.profilesProvider = profilesProvider
        self.onShortcutRecordingChanged = onShortcutRecordingChanged
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Profile"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.contentView = makeContentView()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
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
        stack.addArrangedSubview(makeShortcutRow())
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
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 90).isActive = true

        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 250).isActive = true

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
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 90).isActive = true

        slider.minValue = Double(min)
        slider.maxValue = Double(max)
        if max - min <= 12 {
            slider.numberOfTickMarks = max - min + 1
            slider.allowsTickMarkValuesOnly = true
        }
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)

        return row
    }

    private func makeShortcutRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Shortcut")
        labelView.widthAnchor.constraint(equalToConstant: 90).isActive = true

        shortcutField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        shortcutField.onShortcutRecorded = { [weak self] shortcut in
            self?.handleRecordedShortcut(shortcut)
        }
        shortcutField.onRecordingChanged = { [weak self] isRecording in
            self?.onShortcutRecordingChanged(isRecording)
        }

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearShortcutClicked))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(shortcutField)
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
        row.widthAnchor.constraint(equalToConstant: 392).isActive = true

        return row
    }

    private func refresh() {
        nameField.stringValue = profile.name
        rowsSlider.integerValue = profile.rows
        columnsSlider.integerValue = profile.columns
        gapSlider.integerValue = profile.gap
        refreshSliderLabels()
        shortcutField.setShortcut(profile.shortcut)
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

    @objc private func sliderChanged(_ sender: NSSlider) {
        refreshSliderLabels()
    }

    @objc private func clearShortcutClicked() {
        profile.shortcut = nil
        shortcutField.setShortcut(nil)
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

        guard let window else {
            return
        }

        window.sheetParent?.endSheet(window)
    }

    private func handleRecordedShortcut(_ shortcut: KeyboardShortcut) {
        let normalizedShortcut = shortcut.normalized()

        guard let conflictingProfile = profilesProvider().first(where: {
            $0.id != profile.id && $0.shortcut?.normalized() == normalizedShortcut
        }) else {
            profile.shortcut = normalizedShortcut
            shortcutField.setShortcut(normalizedShortcut)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Replace Shortcut?"
        alert.informativeText = "\(normalizedShortcut.displayName) is already assigned to \"\(conflictingProfile.name)\". Replace it?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            profile.shortcut = normalizedShortcut
            shortcutField.setShortcut(normalizedShortcut)
        } else {
            shortcutField.setShortcut(profile.shortcut)
        }
    }
}
