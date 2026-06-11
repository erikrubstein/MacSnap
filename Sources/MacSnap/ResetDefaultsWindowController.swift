import AppKit
import MacSnapCore

@MainActor
final class ResetDefaultsWindowController: NSWindowController {
    private let profilesSwitch = NSSwitch()
    private let displaysSwitch = NSSwitch()
    private let globalSwitch = NSSwitch()
    private let appearanceSwitch = NSSwitch()
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let onReset: (Set<SettingsStore.ResetSection>) -> Void

    init(onReset: @escaping (Set<SettingsStore.ResetSection>) -> Void) {
        self.onReset = onReset

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 285),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Reset Defaults"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.contentView = makeContentView()
        configureDefaults()
        refreshResetButton()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func makeContentView() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Choose What to Reset")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        let bodyLabel = NSTextField(wrappingLabelWithString: "Selected sections will be restored to their default values.")
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(makeSwitchRow(title: "Profiles", toggle: profilesSwitch))
        stack.addArrangedSubview(makeSwitchRow(title: "Displays", toggle: displaysSwitch))
        stack.addArrangedSubview(makeSwitchRow(title: "Global", toggle: globalSwitch))
        stack.addArrangedSubview(makeSwitchRow(title: "Appearance", toggle: appearanceSwitch))
        stack.setCustomSpacing(22, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeButtonRow())

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -18)
        ])

        return container
    }

    private func makeSwitchRow(title: String, toggle: NSSwitch) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 360).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)

        let spacer = NSView()
        toggle.target = self
        toggle.action = #selector(toggleChanged)

        row.addArrangedSubview(label)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(toggle)
        return row
    }

    private func makeButtonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: 360).isActive = true

        let spacer = NSView()
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        resetButton.target = self
        resetButton.action = #selector(resetClicked)

        row.addArrangedSubview(spacer)
        row.addArrangedSubview(cancelButton)
        row.addArrangedSubview(resetButton)
        return row
    }

    private func configureDefaults() {
        profilesSwitch.state = .off
        displaysSwitch.state = .on
        globalSwitch.state = .on
        appearanceSwitch.state = .on
    }

    private var selectedSections: Set<SettingsStore.ResetSection> {
        var sections = Set<SettingsStore.ResetSection>()
        if profilesSwitch.state == .on {
            sections.insert(.profiles)
        }
        if displaysSwitch.state == .on {
            sections.insert(.displays)
        }
        if globalSwitch.state == .on {
            sections.insert(.global)
        }
        if appearanceSwitch.state == .on {
            sections.insert(.appearance)
        }
        return sections
    }

    private func refreshResetButton() {
        resetButton.isEnabled = !selectedSections.isEmpty
    }

    private func closeSheet() {
        guard let window else {
            return
        }

        window.sheetParent?.endSheet(window)
    }

    @objc private func toggleChanged() {
        refreshResetButton()
    }

    @objc private func cancelClicked() {
        closeSheet()
    }

    @objc private func resetClicked() {
        onReset(selectedSections)
        closeSheet()
    }
}
